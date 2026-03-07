# OpenClaw Exec-Approvals Health Check

[![Language: Bash](https://img.shields.io/badge/language-bash-green)]()

> **[README on Russian / README на русском](README.ru.md)**

A bash script for safe health check and configuration of `exec-approvals.json` on your OpenClaw VM.

If you just installed OpenClaw and don't know how to properly configure execution approvals — run this script. It will validate your current config, set secure defaults, and add standard system utilities to the allowlist.

## Why?

OpenClaw uses `~/.openclaw/exec-approvals.json` to control which binaries the agent can execute on the host. Without proper configuration:

- The agent may be blocked on harmless commands (`cat`, `ls`, `grep`)
- Or have overly broad permissions (`security: "full"`)
- Per-agent overrides (like `ask: "always"`) can conflict with defaults

This script sets a **recommended baseline**: `allowlist` mode + standard Linux utilities + clean agent inheritance.

## What the script does

| Step | Action | Safety |
|------|--------|--------|
| 1 | Creates a timestamped backup of the config | Can rollback anytime |
| 2 | Validates config exists and is valid JSON | Won't touch broken files |
| 3 | Normalizes `defaults` (security, ask, askFallback, autoAllowSkills) | Sets secure values |
| 4 | Removes per-agent overrides (security, ask, askFallback) | Agents inherit from defaults cleanly |
| 5 | Adds missing system utilities to **every agent's** allowlist | No duplicates, preserves existing entries |
| 6 | Restarts the gateway | Applies changes |
| 7 | Offers to restore backup on error | Interactive rollback |

### Safety features

- **safe_mv** — before overwriting config, validates that the new file is non-empty and valid JSON. Prevents data loss if `jq` fails.
- **ERR trap** — on any error, the script offers to restore the backup interactively.
- **Idempotent** — safe to run multiple times. Only adds what's missing, never duplicates.

### Defaults applied

```json
{
  "defaults": {
    "security": "allowlist",
    "ask": "off",
    "askFallback": "deny",
    "autoAllowSkills": true
  }
}
```

- `security: "allowlist"` — only allowlisted binaries can run
- `ask: "off"` — no confirmation prompts for allowlisted binaries
- `askFallback: "deny"` — block execution when UI is unavailable
- `autoAllowSkills: true` — auto-allow binaries from installed skills

### Per-agent overrides

The script removes `security`, `ask`, and `askFallback` from individual agents so they inherit from `defaults`. Per [OpenClaw docs](https://docs.openclaw.ai/tools/exec-approvals), this is the recommended approach — override only when an agent needs stricter or more permissive policies. Allowlists are preserved.

### Binaries added to allowlist

The script ensures 37 entries are present in `agents["*"].allowlist`:

**Shell & interpreters:**
`/usr/bin/env`, `/bin/sh`, `/usr/bin/bash`, `/usr/bin/python3`, `/usr/bin/node`

**Network:** `/usr/bin/curl`

**Text processing:**
`grep`, `cat`, `sed`, `awk`, `sort`, `uniq`, `head`, `tail`, `cut`, `tr`, `wc`, `printf`

**Files & directories:**
`find`, `xargs`, `ls`, `pwd`, `mkdir`, `rm`, `cp`, `mv`

**Inspection:**
`test`, `which`, `stat`, `file`, `date`

**Paths:**
`dirname`, `basename`, `realpath`, `readlink`

**Skills:**
`~/.local/bin/tg-reader*` (Telegram channel reader)

**Virtual environments:**
`~/.venv/*/bin/python3` (python3 from any venv)

> Allowlists are per-agent in OpenClaw (no inheritance). The script adds missing entries to **every** agent's allowlist. Existing entries with `id`, `lastUsedAt`, and other metadata are preserved.

## Requirements

- **OS:** Ubuntu / Debian (or any Linux with `bash`)
- **jq:** `sudo apt install jq`
- **OpenClaw:** installed and initialized (`~/.openclaw/exec-approvals.json` must exist)

## Installation & usage

```bash
# Clone
git clone https://github.com/bzSega/SMTools-OpenClaw-Exec-Approvals-Health-Check.git
cd SMTools-OpenClaw-Exec-Approvals-Health-Check

# Make executable
chmod +x openclaw-exec-approvals-health-check.sh

# Run
./openclaw-exec-approvals-health-check.sh
```

### Example output

```
Found config: /home/user/.openclaw/exec-approvals.json
Backup created: /home/user/.openclaw/exec-approvals.backup.20260307_153042.json
Defaults normalized
  Agent "main": removed security=full (inherits from defaults)
  Agent "main": removed ask=always (inherits from defaults)
  Agent "main": removed askFallback=full (inherits from defaults)
Agent overrides cleaned
  + /usr/bin/curl
  + /usr/bin/tr
Allowlist: added 2, already present 34
Restarting gateway...
Done. Backup: /home/user/.openclaw/exec-approvals.backup.20260307_153042.json
To rollback: cp '...' '~/.openclaw/exec-approvals.json' && openclaw gateway restart
```

### Verify after running

```bash
openclaw approvals get
```

## Rollback

If something goes wrong:

```bash
# The script will offer to restore automatically on error.
# Or manually:
cp ~/.openclaw/exec-approvals.backup.YYYYMMDD_HHMMSS.json ~/.openclaw/exec-approvals.json
openclaw gateway restart
```

## Tests

The project includes 13 automated tests covering all scenarios:

```bash
bash tests/run-tests.sh
```

Tests run in isolated temp directories and never touch your real config.

### What the tests cover

- Backup is created and matches the original
- Incorrect defaults are fixed
- Empty allowlist is fully populated
- Existing entries (id, lastUsedAt) are preserved
- No duplicates are added
- Errors on missing config or invalid JSON
- Version and socket fields are preserved
- `main` agent allowlist is not modified
- New entries go to `agents["*"]`, not `agents["main"]`
- Per-agent security/ask/askFallback overrides are removed
- Gateway restart command is executed

### Pre-push hook

Tests run automatically before `git push`:

```bash
# One-time setup after cloning
cat > .git/hooks/pre-push << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Running tests before push..."
bash "$(git rev-parse --show-toplevel)/tests/run-tests.sh"
echo "Tests passed, pushing..."
EOF
chmod +x .git/hooks/pre-push
```

## Known issues

### Sandbox overrides exec-approvals (`ask: off` still prompts)

Even with correct exec-approvals config (`ask: off`, `security: allowlist`), approval prompts may still appear. This is caused by `agents.defaults.sandbox.mode` defaulting to `"non-main"`, which silently overrides exec-approvals settings ([Issue #31036](https://github.com/openclaw/openclaw/issues/31036)).

**Workaround:**

```bash
openclaw config set agents.defaults.sandbox.mode off
systemctl --user restart openclaw-gateway.service
```

### Related OpenClaw issues

- [#31036](https://github.com/openclaw/openclaw/issues/31036) — sandbox.mode silently conflicts with exec-approvals
- [#20141](https://github.com/openclaw/openclaw/issues/20141) — "Always Allow + Never Ask" still prompts (fix pending)
- [#26496](https://github.com/openclaw/openclaw/issues/26496) — exec-approvals.sock not created on headless Linux

## OpenClaw documentation

- [Exec Approvals](https://docs.openclaw.ai/tools/exec-approvals) — config format, allowlist, patterns
- [Exec Tool](https://docs.openclaw.ai/tools/exec) — how command execution works
- [Approvals CLI](https://docs.openclaw.ai/cli/approvals) — `openclaw approvals get/set/allowlist`
- [Skills](https://docs.openclaw.ai/cli/skills) — skills and autoAllowSkills
- [Tools Overview](https://docs.openclaw.ai/tools) — all OpenClaw tools

## License

MIT
