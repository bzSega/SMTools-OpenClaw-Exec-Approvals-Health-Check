# OpenClaw Exec-Approvals Health Check

## Documentation References

Always consult these docs when working on this project:

- Exec Approvals: https://docs.openclaw.ai/tools/exec-approvals
- Exec Tool: https://docs.openclaw.ai/tools/exec
- Tools Overview: https://docs.openclaw.ai/tools
- Skills: https://docs.openclaw.ai/cli/skills
- General Docs: https://docs.openclaw.ai/

## Project Overview

Interactive bash script for safe health check and configuration of OpenClaw exec-approvals on VM.
Config path: `~/.openclaw/exec-approvals.json`
Dependency: `jq`

## Key Principles

- Always backup before changes
- Never break existing allowlist entries
- Offer rollback on errors
- Restart gateway after changes

## CLI Modes

- `./script.sh` — interactive TUI menu to select permission groups
- `./script.sh --all` — add all 46 binaries (backward compat with v1.0)
- `./script.sh --no-agents-md` — skip AGENTS.md modification
- `./script.sh --help` / `--version` — help and version
- Non-terminal stdin auto-fallback to `--all`

## Permission Groups (12 groups, 46 binaries)

Groups 1-6 are ON by default (essential), groups 7-12 are OFF (opt-in):

1. Shell interpreters (env, sh, bash)
2. Script interpreters (python3, node)
3. Text processing (grep, cat, sed, awk, sort, uniq, head, tail, cut, tr, wc, printf)
4. File management (ls, pwd, mkdir, rm, cp, mv, chmod, touch)
5. File discovery (find, xargs, which, dirname, basename, realpath, readlink)
6. File inspection (stat, file, test)
7. System & time (date, printenv, crontab)
8. Network (curl)
9. Package managers (pip, pip3)
10. Multimedia (ffmpeg, ffprobe)
11. OpenClaw CLI (openclaw)
12. Custom skills (tg-reader*, venv python3)

## AGENTS.md Auto-Update

The script manages `~/.openclaw/workspace/AGENTS.md` with Shell Command Rules that prevent the agent from using redirections (`2>/dev/null`, `2>&1`) and pipes (`|`) which are rejected in allowlist mode. Chaining (`&&`, `||`, `;`) is allowed since v2026.3.7.

## Testing

21 automated tests in `tests/run-tests.sh`. All tests use `--all --no-agents-md` for isolation. AGENTS.md tests (17-21) use `OPENCLAW_AGENTS_MD` env var for isolation.

## Environment Variables for Testing

- `OPENCLAW_CONFIG` — path to exec-approvals.json
- `OPENCLAW_BACKUP_DIR` — backup directory
- `OPENCLAW_GATEWAY_CMD` — gateway restart command
- `OPENCLAW_AGENTS_MD` — path to AGENTS.md
