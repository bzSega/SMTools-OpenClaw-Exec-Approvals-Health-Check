#!/usr/bin/env bash
set -euo pipefail

VERSION="2.0.2"
CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/exec-approvals.json}"
BACKUP=""
GATEWAY_CMD="${OPENCLAW_GATEWAY_CMD:-openclaw gateway restart}"
AGENTS_MD="${OPENCLAW_AGENTS_MD:-$HOME/.openclaw/workspace/AGENTS.md}"

MODE="interactive"
SKIP_AGENTS_MD=false

# --- CLI argument parsing ---
show_help() {
  cat << 'HELP'
Usage: openclaw-exec-approvals-health-check.sh [OPTIONS]

Interactive health check and configuration tool for OpenClaw exec-approvals.

Options:
  --all            Add all permission groups without interactive menu
  --no-agents-md   Skip AGENTS.md modification
  --help, -h       Show this help message
  --version, -v    Show version

Examples:
  ./openclaw-exec-approvals-health-check.sh           # Interactive mode
  ./openclaw-exec-approvals-health-check.sh --all      # Add all 45 binaries
  ./openclaw-exec-approvals-health-check.sh --all --no-agents-md  # Non-interactive, skip AGENTS.md
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)          MODE="all"; shift ;;
    --no-agents-md) SKIP_AGENTS_MD=true; shift ;;
    --help|-h)      show_help; exit 0 ;;
    --version|-v)   echo "v$VERSION"; exit 0 ;;
    *)              echo "Unknown flag: $1"; show_help; exit 1 ;;
  esac
done

# Non-terminal stdin: fallback to --all
if [[ "$MODE" == "interactive" ]] && ! [[ -t 0 ]]; then
  MODE="all"
fi

# --- cleanup on error ---
cleanup_on_error() {
  if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    echo ""
    echo "--- ERROR DETECTED ---"
    echo "Something went wrong. Your original config was backed up."
    echo ""
    if [[ -t 0 ]]; then
      read -rp "Restore backup? [Y/n]: " answer
      answer="${answer:-Y}"
    else
      answer="Y"
    fi
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      cp "$BACKUP" "$CONFIG"
      echo "Backup restored: $CONFIG"
    else
      echo "Backup kept at: $BACKUP"
      echo "You can restore manually: cp '$BACKUP' '$CONFIG'"
    fi
  fi
}
trap cleanup_on_error ERR

# --- safe move: only overwrite config if tmp is valid ---
safe_mv() {
  local src="$1" dst="$2"
  if [ ! -s "$src" ]; then
    echo "ERROR: jq produced empty output, config not overwritten"
    rm -f "$src"
    return 1
  fi
  if ! jq empty "$src" 2>/dev/null; then
    echo "ERROR: jq produced invalid JSON, config not overwritten"
    rm -f "$src"
    return 1
  fi
  mv "$src" "$dst"
}

# --- check config exists ---
if [ ! -f "$CONFIG" ]; then
  echo "Config not found: $CONFIG"
  echo "Create it first or run: openclaw gateway init"
  exit 1
fi

echo "Found config: $CONFIG"

# --- check jq ---
if ! command -v jq &>/dev/null; then
  echo "jq is required but not installed."
  echo "Install: sudo apt install jq"
  exit 1
fi

# --- validate JSON ---
if ! jq empty "$CONFIG" 2>/dev/null; then
  echo "Config is not valid JSON: $CONFIG"
  exit 1
fi

# --- backup ---
BACKUP_DIR="${OPENCLAW_BACKUP_DIR:-$(dirname "$CONFIG")}"
BACKUP="$BACKUP_DIR/exec-approvals.backup.$(date +%Y%m%d_%H%M%S).json"
cp "$CONFIG" "$BACKUP"
echo "Backup created: $BACKUP"

# --- ensure defaults ---
TMP=$(mktemp)
jq '
.defaults.security = "allowlist" |
.defaults.ask = "off" |
.defaults.askFallback = "deny" |
.defaults.autoAllowSkills = true
' "$CONFIG" > "$TMP"

safe_mv "$TMP" "$CONFIG"
echo "Defaults normalized"

# --- remove per-agent overrides (inherit from defaults) ---
CLEAN_FIELDS=("security" "ask" "askFallback")
jq -r '.agents | keys[]' "$CONFIG" | while IFS= read -r agent; do
  for field in "${CLEAN_FIELDS[@]}"; do
    HAS_FIELD=$(jq --arg a "$agent" --arg f "$field" '.agents[$a] | has($f)' "$CONFIG")
    if [ "$HAS_FIELD" = "true" ]; then
      OLD_VAL=$(jq -r --arg a "$agent" --arg f "$field" '.agents[$a][$f]' "$CONFIG")
      TMP=$(mktemp)
      jq --arg a "$agent" --arg f "$field" 'del(.agents[$a][$f])' "$CONFIG" > "$TMP"
      safe_mv "$TMP" "$CONFIG"
      echo "  Agent \"$agent\": removed $field=$OLD_VAL (inherits from defaults)"
    fi
  done
done
echo "Agent overrides cleaned"

# =====================================================================
# Permission Groups
# =====================================================================

GROUP_NAMES=(
  "Shell interpreters"
  "Script interpreters"
  "Text processing"
  "File management"
  "File discovery"
  "File inspection"
  "System & time"
  "Network"
  "Package managers"
  "Multimedia"
  "OpenClaw CLI"
  "Custom skills"
)

GROUP_DESCS=(
  "Run shell scripts and commands (env, sh, bash)"
  "Run Python and Node.js scripts (python3, node)"
  "Search and process text data (grep, sed, awk...)"
  "Manage files and directories (ls, cp, mv, rm...)"
  "Find files and resolve paths (find, which...)"
  "Inspect file types and metadata (stat, file, test)"
  "Date/time, environment, scheduled tasks (date, printenv, crontab)"
  "Make HTTP/HTTPS requests (curl)"
  "Install Python packages (pip, pip3)"
  "Process audio and video (ffmpeg, ffprobe)"
  "OpenClaw operations and skill execution (openclaw)"
  "Skill binaries and virtual environments"
)

# 1=selected by default, 0=not
GROUP_DEFAULTS=(1 1 1 1 1 1 0 0 0 0 0 0)

GROUP_BINS=(
  "/usr/bin/env /bin/sh /usr/bin/bash"
  "/usr/bin/python3 /usr/bin/node"
  "/usr/bin/grep /usr/bin/cat /usr/bin/sed /usr/bin/awk /usr/bin/sort /usr/bin/uniq /usr/bin/head /usr/bin/tail /usr/bin/cut /usr/bin/tr /usr/bin/wc /usr/bin/printf"
  "/usr/bin/ls /usr/bin/pwd /usr/bin/mkdir /usr/bin/rm /usr/bin/cp /usr/bin/mv /usr/bin/chmod /usr/bin/touch"
  "/usr/bin/find /usr/bin/xargs /usr/bin/which /usr/bin/dirname /usr/bin/basename /usr/bin/realpath /usr/bin/readlink"
  "/usr/bin/stat /usr/bin/file /usr/bin/test"
  "/usr/bin/date /usr/bin/printenv /usr/bin/crontab"
  "/usr/bin/curl"
  "/usr/bin/pip /usr/bin/pip3"
  "/usr/bin/ffmpeg /usr/bin/ffprobe"
  "/usr/bin/openclaw"
  "\$HOME/.local/bin/tg-reader* \$HOME/.venv/*/bin/python3"
)

GROUP_COUNT=${#GROUP_NAMES[@]}

# Initialize selection
SELECTED=()
for i in "${!GROUP_DEFAULTS[@]}"; do
  SELECTED+=("${GROUP_DEFAULTS[$i]}")
done

# =====================================================================
# Interactive Menu
# =====================================================================

show_menu() {
  local cursor=0
  local key

  # Hide cursor, save terminal state
  tput civis
  trap 'tput cnorm; stty sane' RETURN

  # Print header (static)
  echo ""
  echo "  OpenClaw Exec-Approvals Health Check v$VERSION"
  echo ""
  echo "  Select permission groups to enable:"
  echo "  (arrow keys = navigate, space = toggle, enter = confirm, a = all, n = none)"
  echo ""

  while true; do
    # Move cursor up to redraw menu (GROUP_COUNT lines)
    if [[ $cursor -ge 0 ]]; then
      for (( i=0; i<GROUP_COUNT; i++ )); do
        tput cuu1 2>/dev/null || printf '\033[1A'
      done
    fi

    # Draw menu items
    for (( i=0; i<GROUP_COUNT; i++ )); do
      tput el 2>/dev/null || printf '\033[K'  # clear line

      local check=" "
      [[ "${SELECTED[$i]}" == "1" ]] && check="x"

      local prefix="  "
      if [[ $i -eq $cursor ]]; then
        # Highlight current row
        tput rev 2>/dev/null || printf '\033[7m'
        prefix="> "
      fi

      printf '%s[%s] %-22s — %s\n' "$prefix" "$check" "${GROUP_NAMES[$i]}" "${GROUP_DESCS[$i]}"

      if [[ $i -eq $cursor ]]; then
        tput sgr0 2>/dev/null || printf '\033[0m'
      fi
    done

    # Read keypress
    IFS= read -rsn1 key

    case "$key" in
      $'\x1B')  # Escape sequence (arrow keys)
        read -rsn2 key
        case "$key" in
          '[A') cursor=$(( (cursor - 1 + GROUP_COUNT) % GROUP_COUNT )) ;;  # Up
          '[B') cursor=$(( (cursor + 1) % GROUP_COUNT )) ;;                # Down
          'OA') cursor=$(( (cursor - 1 + GROUP_COUNT) % GROUP_COUNT )) ;;  # Up (alt)
          'OB') cursor=$(( (cursor + 1) % GROUP_COUNT )) ;;                # Down (alt)
        esac
        ;;
      ' ')  # Space - toggle selection
        if [[ "${SELECTED[$cursor]}" == "1" ]]; then
          SELECTED[$cursor]=0
        else
          SELECTED[$cursor]=1
        fi
        ;;
      'a'|'A')  # Select all
        for (( i=0; i<GROUP_COUNT; i++ )); do
          SELECTED[$i]=1
        done
        ;;
      'n'|'N')  # Select none
        for (( i=0; i<GROUP_COUNT; i++ )); do
          SELECTED[$i]=0
        done
        ;;
      '')  # Enter - confirm
        break
        ;;
    esac
  done

  # Show cursor again
  tput cnorm 2>/dev/null || printf '\033[?25h'
}

# =====================================================================
# Build BINARIES from selection
# =====================================================================

if [[ "$MODE" == "all" ]]; then
  for (( i=0; i<GROUP_COUNT; i++ )); do
    SELECTED[$i]=1
  done
  echo "Mode: --all (all permission groups enabled)"
elif [[ "$MODE" == "interactive" ]]; then
  # Print blank lines for menu space, then show menu
  for (( i=0; i<GROUP_COUNT; i++ )); do
    echo ""
  done
  show_menu
  echo ""
fi

# Build BINARIES array from selected groups
BINARIES=()
ENABLED_NAMES=()
for (( i=0; i<GROUP_COUNT; i++ )); do
  if [[ "${SELECTED[$i]}" == "1" ]]; then
    # Expand $HOME in group bins
    local_bins="${GROUP_BINS[$i]}"
    expanded_bins=$(eval echo "$local_bins")
    read -ra bins <<< "$expanded_bins"
    BINARIES+=("${bins[@]}")
    ENABLED_NAMES+=("${GROUP_NAMES[$i]}")
  fi
done

if [[ ${#BINARIES[@]} -eq 0 ]]; then
  echo "No permission groups selected. Skipping allowlist update."
else
  echo "Selected groups: ${ENABLED_NAMES[*]}"
  echo "Binaries to ensure: ${#BINARIES[@]}"

  # =====================================================================
  # Allowlist population (per-agent, no inheritance)
  # =====================================================================

  jq -r '.agents | keys[]' "$CONFIG" | while IFS= read -r agent; do
    AGENT_ADDED=0
    AGENT_SKIPPED=0

    for bin in "${BINARIES[@]}"; do
      EXISTS=$(jq --arg a "$agent" --arg p "$bin" '
        .agents[$a].allowlist[]? | select(.pattern == $p)
      ' "$CONFIG")

      if [ -z "$EXISTS" ]; then
        TMP=$(mktemp)
        jq --arg a "$agent" --arg p "$bin" '
          .agents[$a].allowlist += [{"pattern": $p}]
        ' "$CONFIG" > "$TMP"
        safe_mv "$TMP" "$CONFIG"
        echo "  [$agent] + $bin"
        AGENT_ADDED=$((AGENT_ADDED + 1))
      else
        AGENT_SKIPPED=$((AGENT_SKIPPED + 1))
      fi
    done

    echo "  Agent \"$agent\": added $AGENT_ADDED, already present $AGENT_SKIPPED"
  done

  echo "Allowlist populated"
fi

# --- restart gateway ---
# Note: since v2026.3.11 allowlist changes apply without restart,
# but we restart anyway to ensure all config changes take effect.
echo "Restarting gateway (optional since v2026.3.11, but recommended)..."
$GATEWAY_CMD

# =====================================================================
# AGENTS.md auto-update
# =====================================================================

AGENTS_MD_BLOCK='## Shell Command Rules

**IMPORTANT: When executing shell commands, follow these rules strictly:**

- **NEVER use `2>/dev/null`, `2>&1`** or any redirections — they are rejected in allowlist mode
- **NEVER use pipes** (`|`) — they are rejected in allowlist mode
- **Prefer absolute paths** to scripts when possible
- **Chaining (`&&`, `||`, `;`) is OK** — as long as every command in the chain is in the allowlist

**Examples:**
- BAD:  `find /path -name "*.txt" 2>/dev/null`
- GOOD: `find /path -name "*.txt"`
- BAD:  `ffmpeg -i input.ogg output.wav 2>&1 | head -20`
- GOOD: `ffmpeg -i input.ogg output.wav`
- BAD:  `ls /path 2>/dev/null || echo "not found"`
- GOOD: `ls /path`
- OK:   `cd /path/to/skill && python3 scripts/run.py`
- OK:   `mkdir -p /tmp/out && cp file.txt /tmp/out/`

**Why these rules matter:**
1. OpenClaw allowlist mode rejects redirections and pipes
2. The exec tool already captures both stdout AND stderr —
   `2>/dev/null` and `2>&1` are unnecessary, you see all errors anyway
3. Chaining works since v2026.3.7 when every segment is allowlisted

**Exception:** Only use redirections when explicitly debugging
or when the user specifically requests it.'

update_agents_md() {
  echo ""
  echo "--- AGENTS.md Shell Command Rules ---"

  if [ -f "$AGENTS_MD" ]; then
    if grep -q "Shell Command Rules" "$AGENTS_MD" 2>/dev/null; then
      echo "  AGENTS.md already contains Shell Command Rules"
      echo "  File: $AGENTS_MD"
      return 0
    fi

    # File exists but lacks rules — ask to append
    echo "  AGENTS.md found: $AGENTS_MD"
    echo "  Shell Command Rules not found in file."
    echo ""

    local answer="Y"
    if [[ -t 0 ]]; then
      read -rp "  Add Shell Command Rules to AGENTS.md? [Y/n]: " answer
      answer="${answer:-Y}"
    fi

    if [[ "$answer" =~ ^[Yy]$ ]]; then
      local agents_backup="${AGENTS_MD}.backup.$(date +%Y%m%d_%H%M%S)"
      cp "$AGENTS_MD" "$agents_backup"
      echo "  Backup: $agents_backup"

      printf '\n%s\n' "$AGENTS_MD_BLOCK" >> "$AGENTS_MD"
      echo "  Shell Command Rules appended to AGENTS.md"
    else
      echo "  Skipped AGENTS.md update"
    fi
  else
    # File does not exist — ask to create
    echo "  AGENTS.md not found: $AGENTS_MD"
    echo ""

    local answer="Y"
    if [[ -t 0 ]]; then
      read -rp "  Create AGENTS.md with Shell Command Rules? [Y/n]: " answer
      answer="${answer:-Y}"
    fi

    if [[ "$answer" =~ ^[Yy]$ ]]; then
      local agents_dir
      agents_dir=$(dirname "$AGENTS_MD")
      mkdir -p "$agents_dir"
      printf '%s\n' "$AGENTS_MD_BLOCK" > "$AGENTS_MD"
      echo "  AGENTS.md created: $AGENTS_MD"
    else
      echo "  Skipped AGENTS.md creation"
    fi
  fi
}

if [[ "$SKIP_AGENTS_MD" == "true" ]]; then
  echo "Skipping AGENTS.md update (--no-agents-md)"
else
  update_agents_md
fi

# =====================================================================
# Summary
# =====================================================================

echo ""
echo "============================================================"
echo "  Done!"
echo "============================================================"
echo ""
if [[ ${#ENABLED_NAMES[@]} -gt 0 ]]; then
  echo "  Enabled groups: ${ENABLED_NAMES[*]}"
  echo "  Binaries: ${#BINARIES[@]} entries in every agent's allowlist"
fi
echo "  Config backup: $BACKUP"
echo "  To rollback: cp '$BACKUP' '$CONFIG' && openclaw gateway restart"
echo "============================================================"
