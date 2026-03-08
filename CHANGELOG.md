# Changelog

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
- `chmod`, `touch` added to allowlist (44 entries total)
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
