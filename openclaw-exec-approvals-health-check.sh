#!/usr/bin/env bash
set -euo pipefail

CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/exec-approvals.json}"
BACKUP=""
GATEWAY_CMD="${OPENCLAW_GATEWAY_CMD:-openclaw gateway restart}"

# --- cleanup on error ---
cleanup_on_error() {
  if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    echo ""
    echo "--- ERROR DETECTED ---"
    echo "Something went wrong. Your original config was backed up."
    echo ""
    read -rp "Restore backup? [Y/n]: " answer
    answer="${answer:-Y}"
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

# --- binaries to ensure in allowlist ---
BINARIES=(
  "/usr/bin/env"
  "/bin/sh"
  "/usr/bin/bash"
  "/usr/bin/python3"
  "/usr/bin/node"
  "/usr/bin/curl"
  "/usr/bin/grep"
  "/usr/bin/cat"
  "/usr/bin/sed"
  "/usr/bin/awk"
  "/usr/bin/sort"
  "/usr/bin/uniq"
  "/usr/bin/head"
  "/usr/bin/tail"
  "/usr/bin/cut"
  "/usr/bin/tr"
  "/usr/bin/wc"
  "/usr/bin/find"
  "/usr/bin/xargs"
  "/usr/bin/printf"
  "/usr/bin/date"
  "/usr/bin/ls"
  "/usr/bin/pwd"
  "/usr/bin/test"
  "/usr/bin/which"
  "/usr/bin/stat"
  "/usr/bin/file"
  "/usr/bin/chmod"
  "/usr/bin/touch"
  "/usr/bin/mkdir"
  "/usr/bin/rm"
  "/usr/bin/cp"
  "/usr/bin/mv"
  "/usr/bin/dirname"
  "/usr/bin/basename"
  "/usr/bin/realpath"
  "/usr/bin/readlink"
  "/usr/bin/crontab"
  "/usr/bin/pip"
  "/usr/bin/pip3"
  "/usr/bin/ffmpeg"
  "/usr/bin/ffprobe"
  "/usr/bin/openclaw"
  "$HOME/.local/bin/tg-reader*"
  "$HOME/.venv/*/bin/python3"
)

ADDED=0
SKIPPED=0

# Allowlists are per-agent (no inheritance from "*").
# Add binaries to every agent's allowlist.
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

# --- restart gateway ---
echo "Restarting gateway..."
$GATEWAY_CMD

echo ""
echo "Done. Backup: $BACKUP"
echo "To rollback: cp '$BACKUP' '$CONFIG' && openclaw gateway restart"

# --- AGENTS.md recommendation ---
AGENTS_MD="$HOME/.openclaw/workspace/AGENTS.md"
echo ""
echo "============================================================"
echo "  RECOMMENDED: Add Shell Command Rules to AGENTS.md"
echo "============================================================"
echo ""
echo "OpenClaw allowlist mode blocks chaining (&&, ||, ;) and"
echo "redirections (2>/dev/null, >, >>). The agent naturally"
echo "generates these patterns, causing approval prompts even"
echo "when all binaries are in the allowlist."
echo ""
echo "Add the following to your AGENTS.md to instruct the agent"
echo "to generate allowlist-compatible commands:"
echo ""
echo "  File: $AGENTS_MD"
echo ""
echo "--- copy below this line ---"
cat << 'AGENTS_BLOCK'

## Shell Command Rules

**IMPORTANT: When executing shell commands, follow these rules strictly:**

- **NEVER use `cd dir && command`** — use absolute paths instead
- **NEVER use `2>/dev/null`, `2>&1`** or any redirections that hide errors
- **NEVER use `||` or `&&` or `;`** to chain commands — execute each command separately
- **Always call binaries with full absolute paths** to scripts when possible

**Examples:**
- BAD:  `cd /path/to/skill && python3 scripts/run.py`
- GOOD: `python3 /path/to/skill/scripts/run.py`
- BAD:  `find /path -name "*.txt" 2>/dev/null`
- GOOD: `find /path -name "*.txt"`
- BAD:  `ls /path || echo "not found"`
- GOOD: `ls /path`
- BAD:  `ffmpeg -i input.ogg output.wav 2>&1 | head -20`
- GOOD: `ffmpeg -i input.ogg output.wav`

**Why these rules matter:**
1. OpenClaw allowlist mode rejects chaining and redirections
2. The exec tool already captures both stdout AND stderr —
   `2>/dev/null` and `2>&1` are unnecessary, you see all errors anyway
3. Each command should be a single binary call for allowlist validation

**Exception:** Only use chaining/redirection when explicitly debugging
or when the user specifically requests it.
AGENTS_BLOCK
echo "--- copy above this line ---"
echo ""
if [ -f "$AGENTS_MD" ]; then
  if grep -q "Shell Command Rules" "$AGENTS_MD" 2>/dev/null; then
    echo "  ✓ AGENTS.md already contains Shell Command Rules"
  else
    echo "  ⚠ AGENTS.md exists but does not contain Shell Command Rules"
    echo "    Add the block above to: $AGENTS_MD"
  fi
else
  echo "  ⚠ AGENTS.md not found at: $AGENTS_MD"
  echo "    Create the file and paste the block above"
fi
echo "============================================================"
