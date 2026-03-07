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
  "/usr/bin/mkdir"
  "/usr/bin/rm"
  "/usr/bin/cp"
  "/usr/bin/mv"
  "/usr/bin/dirname"
  "/usr/bin/basename"
  "/usr/bin/realpath"
  "/usr/bin/readlink"
  "$HOME/.local/bin/tg-reader*"
)

ADDED=0
SKIPPED=0

for bin in "${BINARIES[@]}"; do

  EXISTS=$(jq --arg p "$bin" '
    .agents["*"].allowlist[]? | select(.pattern == $p)
  ' "$CONFIG")

  if [ -z "$EXISTS" ]; then
    TMP=$(mktemp)
    jq --arg p "$bin" '
      .agents["*"].allowlist += [{"pattern": $p}]
    ' "$CONFIG" > "$TMP"
    safe_mv "$TMP" "$CONFIG"
    echo "  + $bin"
    ADDED=$((ADDED + 1))
  else
    SKIPPED=$((SKIPPED + 1))
  fi

done

echo "Allowlist: added $ADDED, already present $SKIPPED"

# --- restart gateway ---
echo "Restarting gateway..."
$GATEWAY_CMD

echo ""
echo "Done. Backup: $BACKUP"
echo "To rollback: cp '$BACKUP' '$CONFIG' && openclaw gateway restart"
