# PRD: OpenClaw Exec-Approvals Health Check v2.0

## Goal

Speed up granting the right execution permissions to OpenClaw agents on headless VMs — without opening the Dashboard and without granting unrestricted access.

## Pain Point

OpenClaw agents on headless VMs constantly trigger exec-approval prompts for routine commands. The user faces three problems:

1. **Prompts don't work via Telegram** — the approval UI requires a browser Dashboard, making remote management painful
2. **Dashboard overhead** — every new binary or command pattern requires opening the web UI to approve
3. **No middle ground** — the only alternative is `security: "full"` which grants unrestricted access, which the user explicitly does not want

### Known OpenClaw issues (discovered during development)

| Issue | Status | Description |
|-------|--------|-------------|
| Allowlists are per-agent | By design | Adding binaries to `agents["*"]` does not cover `agents["main"]` — no inheritance |
| [#31036](https://github.com/openclaw/openclaw/issues/31036) | **Open** | `sandbox.mode: "non-main"` silently overrides `ask: off` |
| [#20141](https://github.com/openclaw/openclaw/issues/20141) | **Fixed in v2026.3.7** | "Always Allow + Never Ask" still prompted |
| [#26496](https://github.com/openclaw/openclaw/issues/26496) | **Fixed in v2026.3.7** | `exec-approvals.sock` not created on headless Linux |
| Redirections rejected | By design | `2>/dev/null`, `2>&1`, pipes (`\|`) are rejected in allowlist mode |
| Chaining rejected | **Fixed in v2026.3.7** | `&&`, `\|\|`, `;` now allowed when every segment is allowlisted |

The agent naturally generates redirections and pipes, causing prompts regardless of allowlist completeness. This requires AGENTS.md rules to instruct the agent to avoid these patterns.

## Solution

An interactive bash script that lets the user configure exec-approvals permissions in a controlled, understandable way — without granting full access and without opening the Dashboard. The script works around known OpenClaw issues and applies best practices from the documentation.

## Three Phases

### Phase 1: Interactive Permission Groups (v2.0)

The script presents 12 permission groups with human-readable descriptions. The user selects which groups to enable using an interactive checkbox menu (arrow keys + space + enter). Essential groups (shell, text processing, file management) are pre-selected by default.

**Permission groups:**

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
| 12 | Custom skills | Skill binaries and virtual environments | tg-reader*, venv python3 | OFF |

### Phase 2: AGENTS.md Auto-Update (v2.0)

After configuring permissions, the script offers to update `AGENTS.md` with Shell Command Rules that instruct the agent to avoid redirections and pipes — patterns that are rejected in allowlist mode even when all binaries are allowlisted.

The script:
- Finds AGENTS.md in `~/.openclaw/workspace/`
- Creates a backup before any modification
- Appends Shell Command Rules if not already present
- Creates the file if it doesn't exist

### Phase 3: Skills Scanner (backlog — [GitHub Issue #1](https://github.com/bzSega/SMTools-OpenClaw-Exec-Approvals-Health-Check/issues/1))

Automatically scan `~/.openclaw/workspace/skills/` to discover binaries that installed skills need (e.g., `ffprobe` for media skills, custom Python scripts). Dynamically add them to the allowlist based on actual skill requirements rather than a static list.

## Target Result

The user runs the script on their VM:

```
$ ./openclaw-exec-approvals-health-check.sh
```

They see an interactive menu, select the permission groups they need, and the script:
1. Backs up the current config
2. Normalizes defaults (`security: allowlist`, `ask: off`)
3. Adds selected binaries to every agent's allowlist
4. Updates AGENTS.md with Shell Command Rules
5. Restarts the gateway

After this, the agent runs commands without approval prompts — within the boundaries the user chose.

## CLI Flags

| Flag | Behavior |
|------|----------|
| (none) | Interactive menu |
| `--all` | Add all 45 binaries without menu (v1.0 backward compatibility) |
| `--no-agents-md` | Skip AGENTS.md modification |
| `--help` | Show usage |
| `--version` | Show version |

## Non-Functional Requirements

- **Pure bash** — no dependencies beyond `jq` and standard coreutils
- **Safe by default** — backup before every change, offer rollback on error
- **Idempotent** — running multiple times does not create duplicates
- **Per-agent** — adds binaries to every agent's allowlist (no inheritance assumption)
- **Testable** — env var overrides for config paths, 21+ automated tests
- **Multilingual** — English and Russian documentation
