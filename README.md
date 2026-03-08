# OpenClaw Exec-Approvals Health Check

[![Language: Bash](https://img.shields.io/badge/language-bash-green)]()
[![Version: 2.0](https://img.shields.io/badge/version-2.0-blue)]()

> **[README on Russian / README на русском](README.ru.md)**

An interactive bash script for safe health check and configuration of `exec-approvals.json` on your OpenClaw VM.

If you just installed OpenClaw and don't know how to properly configure execution approvals — run this script. It will validate your current config, set secure defaults, and let you choose which permission groups to enable.

## Why?

OpenClaw uses `~/.openclaw/exec-approvals.json` to control which binaries the agent can execute on the host. Without proper configuration:

- The agent may be blocked on harmless commands (`cat`, `ls`, `grep`)
- Or have overly broad permissions (`security: "full"`)
- Per-agent overrides (like `ask: "always"`) can conflict with defaults
- Redirections (`2>/dev/null`, `2>&1`) and pipes (`|`) are rejected in allowlist mode

This script sets a **recommended baseline**: `allowlist` mode + selected permission groups + AGENTS.md rules + clean agent inheritance.

## Usage modes

| Mode | Command | Description |
|------|---------|-------------|
| Interactive | `./openclaw-exec-approvals-health-check.sh` | TUI menu to select permission groups |
| All groups | `./openclaw-exec-approvals-health-check.sh --all` | Add all 45 binaries without menu |
| No AGENTS.md | `./openclaw-exec-approvals-health-check.sh --no-agents-md` | Skip AGENTS.md modification |
| Combined | `./openclaw-exec-approvals-health-check.sh --all --no-agents-md` | Non-interactive, skip AGENTS.md |
| Help | `./openclaw-exec-approvals-health-check.sh --help` | Show usage |
| Version | `./openclaw-exec-approvals-health-check.sh --version` | Show version |

Non-terminal stdin (e.g., piped input) automatically falls back to `--all` mode.

## What the script does

| Step | Action | Safety |
|------|--------|--------|
| 1 | Creates a timestamped backup of the config | Can rollback anytime |
| 2 | Validates config exists and is valid JSON | Won't touch broken files |
| 3 | Normalizes `defaults` (security, ask, askFallback, autoAllowSkills) | Sets secure values |
| 4 | Removes per-agent overrides (security, ask, askFallback) | Agents inherit from defaults cleanly |
| 5 | Shows interactive menu to select permission groups | User controls what to allow |
| 6 | Adds selected binaries to **every agent's** allowlist | No duplicates, preserves existing entries |
| 7 | Updates AGENTS.md with Shell Command Rules | Prevents chaining/redirection issues |
| 8 | Restarts the gateway | Applies changes |
| 9 | Offers to restore backup on error | Interactive rollback |

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

## Permission groups

The script organizes 45 binaries into 12 permission groups. In interactive mode, you select which groups to enable:

| # | Group | Description | Binaries | Default |
|---|-------|-------------|----------|---------|
| 1 | Shell interpreters | Run shell scripts and commands | env, sh, bash | ON |
| 2 | Script interpreters | Run Python and Node.js scripts | python3, node | ON |
| 3 | Text processing | Search and process text data | grep, cat, sed, awk, sort, uniq, head, tail, cut, tr, wc, printf | ON |
| 4 | File management | Manage files and directories | ls, pwd, mkdir, rm, cp, mv, chmod, touch | ON |
| 5 | File discovery | Find files and resolve paths | find, xargs, which, dirname, basename, realpath, readlink | ON |
| 6 | File inspection | Inspect file types and metadata | stat, file, test | ON |
| 7 | System & time | Date/time and scheduled tasks | date, crontab | OFF |
| 8 | Network | Make HTTP/HTTPS requests | curl | OFF |
| 9 | Package managers | Install Python packages | pip, pip3 | OFF |
| 10 | Multimedia | Process audio and video | ffmpeg, ffprobe | OFF |
| 11 | OpenClaw CLI | OpenClaw operations and skill execution | openclaw | OFF |
| 12 | Custom skills | Skill binaries and virtual environments | tg-reader\*, venv python3 | OFF |

Groups 1-6 (35 binaries) are pre-selected as essential. Groups 7-12 are opt-in.

> Allowlists are per-agent in OpenClaw (no inheritance). The script adds missing entries to **every** agent's allowlist. Existing entries with `id`, `lastUsedAt`, and other metadata are preserved.

### Interactive menu

```
  OpenClaw Exec-Approvals Health Check v2.0.0

  Select permission groups to enable:
  (arrow keys = navigate, space = toggle, enter = confirm, a = all, n = none)

> [x] Shell interpreters     — Run shell scripts and commands
  [x] Script interpreters    — Run Python and Node.js scripts
  [x] Text processing        — Search and process text data
  [x] File management        — Manage files and directories
  [x] File discovery         — Find files and resolve paths
  [x] File inspection        — Inspect file types and metadata
  [ ] System & time          — Date/time and scheduled tasks
  [ ] Network                — Make HTTP/HTTPS requests
  [ ] Package managers       — Install Python packages
  [ ] Multimedia             — Process audio and video
  [ ] OpenClaw CLI           — OpenClaw operations and skill execution
  [ ] Custom skills          — Skill binaries and virtual environments
```

### AGENTS.md — Shell Command Rules

Even with a complete allowlist, the agent may still trigger approval prompts because it generates commands with redirections (`2>/dev/null`, `2>&1`) and pipes (`|`). These are **rejected in allowlist mode** ([docs](https://docs.openclaw.ai/tools/exec)).

> **Note:** Since v2026.3.7, shell chaining (`&&`, `||`, `;`) **is allowed** when every segment satisfies the allowlist. Redirections and pipes remain unsupported.

The script automatically manages `~/.openclaw/workspace/AGENTS.md`:

- **Creates** the file if it doesn't exist (with Shell Command Rules)
- **Appends** rules if the file exists but doesn't contain them
- **Skips** if rules are already present
- **Creates a backup** before any modification

The Shell Command Rules instruct the agent to:

- No redirections (`2>/dev/null`, `2>&1`) — the exec tool captures both stdout and stderr
- No pipes (`|`) — rejected in allowlist mode
- Chaining (`&&`, `||`, `;`) is OK when every command is allowlisted

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

# Run (interactive mode)
./openclaw-exec-approvals-health-check.sh

# Or add all groups at once
./openclaw-exec-approvals-health-check.sh --all
```

### Example output (--all mode)

```
Found config: /home/user/.openclaw/exec-approvals.json
Backup created: /home/user/.openclaw/exec-approvals.backup.20260308_153042.json
Defaults normalized
  Agent "main": removed security=full (inherits from defaults)
Agent overrides cleaned
Mode: --all (all permission groups enabled)
Selected groups: Shell interpreters Script interpreters Text processing ...
Binaries to ensure: 45
  [main] + /usr/bin/curl
  [main] + /usr/bin/tr
  Agent "main": added 2, already present 43
Allowlist populated
Restarting gateway...

--- AGENTS.md Shell Command Rules ---
  AGENTS.md created: /home/user/.openclaw/workspace/AGENTS.md

============================================================
  Done!
============================================================
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

The project includes 21 automated tests covering all scenarios:

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
- Per-agent security/ask/askFallback overrides are removed
- Gateway restart command is executed
- `--help` and `--version` flags work correctly
- `--all` adds all 45 binaries
- AGENTS.md creation, appending, and skip-if-present
- `--no-agents-md` skips AGENTS.md update
- AGENTS.md backup is created before modification

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

Even with correct exec-approvals config (`ask: off`, `security: allowlist`), approval prompts may still appear. This is caused by `agents.defaults.sandbox.mode` defaulting to `"non-main"`, which silently overrides exec-approvals settings ([Issue #31036](https://github.com/openclaw/openclaw/issues/31036) — still open).

**Workaround:**

```bash
openclaw config set agents.defaults.sandbox.mode off
systemctl --user restart openclaw-gateway.service
```

### Safe bins (v2026.3.7+)

OpenClaw now has built-in "safe bins" that work without explicit allowlist entries: `jq`, `cut`, `uniq`, `head`, `tail`, `tr`, `wc`. These are auto-allowed with restricted argv policies. Our script still adds them to the allowlist for backward compatibility, which does no harm.

See [exec-approvals docs](https://docs.openclaw.ai/tools/exec-approvals) for `tools.exec.safeBins` and `tools.exec.safeBinProfiles`.

### Related OpenClaw issues

- [#31036](https://github.com/openclaw/openclaw/issues/31036) — sandbox.mode silently conflicts with exec-approvals (open)
- [#20141](https://github.com/openclaw/openclaw/issues/20141) — "Always Allow + Never Ask" still prompts — **fixed in v2026.3.7**
- [#26496](https://github.com/openclaw/openclaw/issues/26496) — exec-approvals.sock not created on headless Linux — **fixed in v2026.3.7**

## OpenClaw documentation

- [Exec Approvals](https://docs.openclaw.ai/tools/exec-approvals) — config format, allowlist, patterns
- [Exec Tool](https://docs.openclaw.ai/tools/exec) — how command execution works
- [Approvals CLI](https://docs.openclaw.ai/cli/approvals) — `openclaw approvals get/set/allowlist`
- [Skills](https://docs.openclaw.ai/cli/skills) — skills and autoAllowSkills
- [Tools Overview](https://docs.openclaw.ai/tools) — all OpenClaw tools

## License

MIT
