# OpenClaw Exec-Approvals Health Check

[![Language: Bash](https://img.shields.io/badge/language-bash-green)]()

> **[README on Russian / README на русском](README.ru.md)**

A bash script for safe health check and configuration of `exec-approvals.json` on your OpenClaw VM.

If you just installed OpenClaw and don't know how to properly configure execution approvals — run this script. It will validate your current config, set secure defaults, and add standard system utilities to the allowlist.

## Why?

OpenClaw uses `~/.openclaw/exec-approvals.json` to control which binaries the agent can execute on the host. Without proper configuration:

- The agent may be blocked on harmless commands (`cat`, `ls`, `grep`)
- Or have overly broad permissions (`security: "full"`)

This script sets a **recommended baseline**: `allowlist` mode + standard Linux utilities.

## What the script does

| Step | Action | Safety |
|------|--------|--------|
| 1 | Creates a timestamped backup of the config | Can rollback anytime |
| 2 | Validates config exists and is valid JSON | Won't touch broken files |
| 3 | Normalizes `defaults` (security, ask, askFallback, autoAllowSkills) | Sets secure values |
| 4 | Adds missing system utilities to `agents["*"].allowlist` | No duplicates, preserves existing entries |
| 5 | Restarts the gateway | Applies changes |
| 6 | Offers to restore backup on error | Interactive rollback |

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

### Binaries added to allowlist

The script ensures 35 standard Linux utilities are present:

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

> The script only modifies `agents["*"].allowlist`. Other agent entries (e.g., `main`) are not touched. Existing entries with `id`, `lastUsedAt`, and other metadata are preserved.

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
  + /usr/bin/curl
  + /usr/bin/tr
  + /usr/bin/xargs
  + /usr/bin/stat
  + /usr/bin/file
Allowlist: added 5, already present 30
Restarting gateway...
Done. Backup: /home/user/.openclaw/exec-approvals.backup.20260307_153042.json
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

The project includes 12 automated tests covering all scenarios:

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
- `main` agent is not modified
- Gateway restart is called

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

## OpenClaw documentation

- [Exec Approvals](https://docs.openclaw.ai/tools/exec-approvals) — config format, allowlist, patterns
- [Exec Tool](https://docs.openclaw.ai/tools/exec) — how command execution works
- [Skills](https://docs.openclaw.ai/cli/skills) — skills and autoAllowSkills
- [Tools Overview](https://docs.openclaw.ai/tools) — all OpenClaw tools

## License

MIT
