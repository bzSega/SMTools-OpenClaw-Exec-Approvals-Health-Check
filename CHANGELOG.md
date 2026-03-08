# Changelog

## [2.0.0] - 2026-03-08

### Added
- **Interactive TUI menu**: 12 permission groups with arrow key navigation, space toggle, enter confirm, select all/none shortcuts
- **Permission groups**: 45 binaries organized into 12 user-friendly groups with descriptions and default selections (groups 1-6 ON, groups 7-12 OFF)
- **CLI argument parsing**: `--all`, `--no-agents-md`, `--help`, `--version` flags
- **AGENTS.md auto-update**: creates, appends, or skips Shell Command Rules in `~/.openclaw/workspace/AGENTS.md` with backup before modification
- **Non-terminal stdin detection**: automatically falls back to `--all` mode when not running in a terminal
- `OPENCLAW_AGENTS_MD` env var for test isolation of AGENTS.md path
- 8 new tests (14-21): `--help`, `--version`, `--all` binary count, AGENTS.md creation/append/skip/backup, `--no-agents-md`
- `prd.md` product requirements document

### Changed
- Binaries reorganized from flat array into 12 permission groups with names, descriptions, and default states
- AGENTS.md handling changed from printed recommendation to automatic file management
- All 13 existing tests updated to use `--all --no-agents-md` flags
- Test count: 13 → 21
- `update.sh` now passes `--all` flag to the health check script
- READMEs updated with usage modes, permission groups table, interactive menu preview
- `CLAUDE.md` updated with modes, groups, and env var documentation

## [Unreleased]

### Added
- Per-agent overrides cleanup: removes `security`, `ask`, `askFallback` from individual agents so they inherit from `defaults` (recommended by OpenClaw docs)
- `safe_mv` function: validates temp file is non-empty and valid JSON before overwriting config, preventing data loss on `jq` failure
- `tg-reader*` skill binary added to allowlist via `~/.local/bin/tg-reader*` pattern
- Venv python3 added to allowlist via `~/.venv/*/bin/python3` glob pattern (covers python3 from any virtual environment)
- Allowlist population now adds binaries to **every agent**, not just `agents["*"]` (OpenClaw allowlists are per-agent with no inheritance)
- `jq` availability check before running
- JSON validation before modifying config
- Test 12: verifies per-agent overrides are removed
- Test 13: verifies gateway restart is called
- Known Issues section in README with sandbox.mode workaround and links to OpenClaw issues (#31036, #20141, #26496)
- `pip`, `pip3`, `ffmpeg`, `ffprobe`, `openclaw` added to allowlist
- `chmod`, `touch`, `crontab` added to allowlist (45 entries total)
- AGENTS.md recommendation now explains that exec tool captures stderr (no need for `2>/dev/null`)
- AGENTS.md Shell Command Rules recommendation printed after health check (instructs agent to avoid chaining/redirections incompatible with allowlist mode)

### Fixed
- Arithmetic increment `((ADDED++))` returning exit code 1 when `ADDED=0`, causing ERR trap under `set -e`. Replaced with `$((ADDED + 1))`
- Glob expansion of `*` in agent key iteration (bash was expanding `*` as filename glob). Fixed by using `while IFS= read -r` instead of `for in`

## [1.0.0] - 2026-03-07

### Added
- Initial release
- Backup creation with timestamp before any changes
- Defaults normalization: `security=allowlist`, `ask=off`, `askFallback=deny`, `autoAllowSkills=true`
- Allowlist population with 35 standard Linux utilities
- Interactive rollback on error via ERR trap
- Gateway restart after changes
- 12 automated tests in `tests/run-tests.sh`
- Pre-push git hook for running tests before push
- English and Russian README
