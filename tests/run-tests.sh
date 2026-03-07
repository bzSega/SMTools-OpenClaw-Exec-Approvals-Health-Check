#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HEALTH_CHECK="$PROJECT_DIR/openclaw-exec-approvals-health-check.sh"

PASSED=0
FAILED=0
TOTAL=0

# --- helpers ---
setup_tmpdir() {
  TEST_DIR=$(mktemp -d)
  export OPENCLAW_CONFIG="$TEST_DIR/exec-approvals.json"
  export OPENCLAW_BACKUP_DIR="$TEST_DIR"
  export OPENCLAW_GATEWAY_CMD="echo gateway-restart-stub"
}

teardown_tmpdir() {
  rm -rf "$TEST_DIR"
}

run_test() {
  local name="$1"
  TOTAL=$((TOTAL + 1))
  echo ""
  echo "--- TEST $TOTAL: $name ---"
}

pass() {
  PASSED=$((PASSED + 1))
  echo "  PASS"
}

fail() {
  local msg="${1:-}"
  FAILED=$((FAILED + 1))
  echo "  FAIL: $msg"
}

# --- fixture: realistic config based on real exec-approvals.json ---
# sanitized: no personal paths, no real tokens/UUIDs
create_fixture_realistic() {
  cat > "$OPENCLAW_CONFIG" << 'FIXTURE'
{
  "version": 1,
  "socket": {
    "path": "/home/testuser/.openclaw/exec-approvals.sock",
    "token": "test-token-placeholder"
  },
  "defaults": {
    "security": "allowlist",
    "ask": "off",
    "askFallback": "deny",
    "autoAllowSkills": true
  },
  "agents": {
    "*": {
      "allowlist": [
        {
          "pattern": "/bin/sh"
        },
        {
          "pattern": "/usr/bin/cat",
          "id": "00000000-0000-0000-0000-000000000001"
        },
        {
          "pattern": "/usr/bin/printf",
          "id": "00000000-0000-0000-0000-000000000002"
        },
        {
          "pattern": "/usr/bin/bash",
          "id": "00000000-0000-0000-0000-000000000003"
        },
        {
          "pattern": "/usr/bin/python3",
          "id": "00000000-0000-0000-0000-000000000004"
        },
        {
          "pattern": "/usr/bin/node",
          "id": "00000000-0000-0000-0000-000000000005"
        },
        {
          "pattern": "/usr/bin/env",
          "id": "00000000-0000-0000-0000-000000000006"
        },
        {
          "pattern": "/bin/sh",
          "id": "00000000-0000-0000-0000-000000000007"
        },
        {
          "pattern": "/usr/bin/bash",
          "id": "00000000-0000-0000-0000-000000000008"
        },
        {
          "pattern": "/usr/bin/cat",
          "id": "00000000-0000-0000-0000-000000000009"
        },
        {
          "pattern": "/usr/bin/sed",
          "id": "00000000-0000-0000-0000-000000000010"
        },
        {
          "pattern": "/usr/bin/awk",
          "id": "00000000-0000-0000-0000-000000000011"
        },
        {
          "pattern": "/usr/bin/sort",
          "id": "00000000-0000-0000-0000-000000000012"
        },
        {
          "pattern": "/usr/bin/uniq",
          "id": "00000000-0000-0000-0000-000000000013"
        },
        {
          "pattern": "/usr/bin/tail",
          "id": "00000000-0000-0000-0000-000000000014"
        },
        {
          "pattern": "/usr/bin/cut",
          "id": "00000000-0000-0000-0000-000000000015"
        },
        {
          "pattern": "/usr/bin/bash",
          "lastUsedAt": 1772517700159,
          "id": "00000000-0000-0000-0000-000000000016"
        },
        {
          "pattern": "/usr/bin/python3",
          "lastUsedAt": 1772517723764,
          "id": "00000000-0000-0000-0000-000000000017"
        },
        {
          "pattern": "/usr/bin/node",
          "lastUsedAt": 1772517736859,
          "id": "00000000-0000-0000-0000-000000000018"
        }
      ],
      "autoAllowSkills": true
    },
    "main": {
      "allowlist": [
        {
          "id": "00000000-0000-0000-0000-000000000020",
          "pattern": "/usr/bin/curl",
          "lastUsedAt": 1772868610073
        },
        {
          "id": "00000000-0000-0000-0000-000000000021",
          "pattern": "/usr/bin/grep",
          "lastUsedAt": 1772877743008
        },
        {
          "id": "00000000-0000-0000-0000-000000000022",
          "pattern": "/usr/bin/ls",
          "lastUsedAt": 1772877743007
        },
        {
          "id": "00000000-0000-0000-0000-000000000023",
          "pattern": "/usr/bin/find",
          "lastUsedAt": 1772877705187
        },
        {
          "id": "00000000-0000-0000-0000-000000000024",
          "pattern": "/usr/bin/head",
          "lastUsedAt": 1772877705190
        },
        {
          "id": "00000000-0000-0000-0000-000000000025",
          "pattern": "/usr/bin/which",
          "lastUsedAt": 1772868814321
        },
        {
          "id": "00000000-0000-0000-0000-000000000026",
          "pattern": "/usr/bin/date",
          "lastUsedAt": 1772870488738
        },
        {
          "id": "00000000-0000-0000-0000-000000000027",
          "pattern": "/usr/bin/mkdir",
          "lastUsedAt": 1772873942689
        },
        {
          "id": "00000000-0000-0000-0000-000000000028",
          "pattern": "/usr/bin/rm",
          "lastUsedAt": 1772870906158
        },
        {
          "id": "00000000-0000-0000-0000-000000000029",
          "pattern": "/usr/bin/pwd",
          "lastUsedAt": 1772877696948
        },
        {
          "id": "00000000-0000-0000-0000-000000000030",
          "pattern": "/usr/bin/test",
          "lastUsedAt": 1772871761325
        },
        {
          "id": "00000000-0000-0000-0000-000000000031",
          "pattern": "/usr/bin/wc",
          "lastUsedAt": 1772871784151
        }
      ]
    }
  }
}
FIXTURE
}

# =============================================
# TEST 1: backup is created before changes
# =============================================
run_test "Backup is created before changes"
setup_tmpdir
create_fixture_realistic

bash "$HEALTH_CHECK" >/dev/null 2>&1

BACKUP_COUNT=$(ls "$TEST_DIR"/exec-approvals.backup.*.json 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -ge 1 ]; then
  pass
else
  fail "No backup file found in $TEST_DIR"
fi
teardown_tmpdir

# =============================================
# TEST 2: defaults are normalized correctly
# =============================================
run_test "Defaults are normalized (even if wrong)"
setup_tmpdir

# Create config with WRONG defaults
cat > "$OPENCLAW_CONFIG" << 'EOF'
{
  "version": 1,
  "defaults": {
    "security": "full",
    "ask": "always",
    "askFallback": "full",
    "autoAllowSkills": false
  },
  "agents": {
    "*": {
      "allowlist": []
    }
  }
}
EOF

bash "$HEALTH_CHECK" >/dev/null 2>&1

SEC=$(jq -r '.defaults.security' "$OPENCLAW_CONFIG")
ASK=$(jq -r '.defaults.ask' "$OPENCLAW_CONFIG")
FALL=$(jq -r '.defaults.askFallback' "$OPENCLAW_CONFIG")
AUTO=$(jq -r '.defaults.autoAllowSkills' "$OPENCLAW_CONFIG")

if [ "$SEC" = "allowlist" ] && [ "$ASK" = "off" ] && [ "$FALL" = "deny" ] && [ "$AUTO" = "true" ]; then
  pass
else
  fail "defaults: security=$SEC ask=$ASK askFallback=$FALL autoAllowSkills=$AUTO"
fi
teardown_tmpdir

# =============================================
# TEST 3: missing binaries are added
# =============================================
run_test "Missing binaries are added to allowlist"
setup_tmpdir

# Minimal config with empty allowlist
cat > "$OPENCLAW_CONFIG" << 'EOF'
{
  "version": 1,
  "defaults": {},
  "agents": {
    "*": {
      "allowlist": []
    }
  }
}
EOF

bash "$HEALTH_CHECK" >/dev/null 2>&1

COUNT=$(jq '.agents["*"].allowlist | length' "$OPENCLAW_CONFIG")
# Script has 35 binaries in the list
if [ "$COUNT" -ge 35 ]; then
  pass
else
  fail "Expected >= 35 entries, got $COUNT"
fi
teardown_tmpdir

# =============================================
# TEST 4: existing entries are NOT broken
# =============================================
run_test "Existing entries preserve id/lastUsedAt metadata"
setup_tmpdir
create_fixture_realistic

bash "$HEALTH_CHECK" >/dev/null 2>&1

# Check that original entry with id is still there
ORIGINAL_ID=$(jq -r '
  .agents["*"].allowlist[]
  | select(.pattern == "/usr/bin/cat" and .id == "00000000-0000-0000-0000-000000000001")
  | .id
' "$OPENCLAW_CONFIG")

# Check that main agent entries are untouched
MAIN_CURL_ID=$(jq -r '
  .agents["main"].allowlist[]
  | select(.pattern == "/usr/bin/curl")
  | .id
' "$OPENCLAW_CONFIG")

if [ "$ORIGINAL_ID" = "00000000-0000-0000-0000-000000000001" ] && [ "$MAIN_CURL_ID" = "00000000-0000-0000-0000-000000000020" ]; then
  pass
else
  fail "Metadata lost: cat.id=$ORIGINAL_ID curl.id=$MAIN_CURL_ID"
fi
teardown_tmpdir

# =============================================
# TEST 5: no duplicates added for existing patterns
# =============================================
run_test "No duplicates added for already-present patterns"
setup_tmpdir
create_fixture_realistic

# Count /bin/sh entries before
BEFORE=$(jq '[.agents["*"].allowlist[] | select(.pattern == "/bin/sh")] | length' "$OPENCLAW_CONFIG")

bash "$HEALTH_CHECK" >/dev/null 2>&1

AFTER=$(jq '[.agents["*"].allowlist[] | select(.pattern == "/bin/sh")] | length' "$OPENCLAW_CONFIG")

if [ "$BEFORE" = "$AFTER" ]; then
  pass
else
  fail "/bin/sh count: before=$BEFORE after=$AFTER"
fi
teardown_tmpdir

# =============================================
# TEST 6: missing config file exits with error
# =============================================
run_test "Missing config file exits with error"
setup_tmpdir
rm -f "$OPENCLAW_CONFIG"

OUTPUT=$(bash "$HEALTH_CHECK" 2>&1 || true)

if echo "$OUTPUT" | grep -q "Config not found"; then
  pass
else
  fail "Expected 'Config not found' message"
fi
teardown_tmpdir

# =============================================
# TEST 7: invalid JSON exits with error
# =============================================
run_test "Invalid JSON exits with error"
setup_tmpdir
echo "this is not json {{{" > "$OPENCLAW_CONFIG"

OUTPUT=$(bash "$HEALTH_CHECK" 2>&1 || true)

if echo "$OUTPUT" | grep -q "not valid JSON"; then
  pass
else
  fail "Expected 'not valid JSON' message"
fi
teardown_tmpdir

# =============================================
# TEST 8: backup content matches original
# =============================================
run_test "Backup content matches original config"
setup_tmpdir
create_fixture_realistic

ORIGINAL_HASH=$(md5sum "$OPENCLAW_CONFIG" 2>/dev/null | cut -d' ' -f1 || md5 -q "$OPENCLAW_CONFIG")

bash "$HEALTH_CHECK" >/dev/null 2>&1

BACKUP_FILE=$(ls "$TEST_DIR"/exec-approvals.backup.*.json 2>/dev/null | head -1)
BACKUP_HASH=$(md5sum "$BACKUP_FILE" 2>/dev/null | cut -d' ' -f1 || md5 -q "$BACKUP_FILE")

if [ "$ORIGINAL_HASH" = "$BACKUP_HASH" ]; then
  pass
else
  fail "Backup hash mismatch"
fi
teardown_tmpdir

# =============================================
# TEST 9: version field is preserved
# =============================================
run_test "Version and socket fields are preserved"
setup_tmpdir
create_fixture_realistic

bash "$HEALTH_CHECK" >/dev/null 2>&1

VERSION=$(jq -r '.version' "$OPENCLAW_CONFIG")
SOCKET_PATH=$(jq -r '.socket.path' "$OPENCLAW_CONFIG")

if [ "$VERSION" = "1" ] && [ "$SOCKET_PATH" = "/home/testuser/.openclaw/exec-approvals.sock" ]; then
  pass
else
  fail "version=$VERSION socket.path=$SOCKET_PATH"
fi
teardown_tmpdir

# =============================================
# TEST 10: main agent allowlist is untouched
# =============================================
run_test "Main agent allowlist is not modified"
setup_tmpdir
create_fixture_realistic

BEFORE_COUNT=$(jq '.agents["main"].allowlist | length' "$OPENCLAW_CONFIG")

bash "$HEALTH_CHECK" >/dev/null 2>&1

AFTER_COUNT=$(jq '.agents["main"].allowlist | length' "$OPENCLAW_CONFIG")

if [ "$BEFORE_COUNT" = "$AFTER_COUNT" ]; then
  pass
else
  fail "main allowlist: before=$BEFORE_COUNT after=$AFTER_COUNT"
fi
teardown_tmpdir

# =============================================
# TEST 11: script adds only to agents["*"]
# =============================================
run_test "New entries go to agents[*], not agents[main]"
setup_tmpdir

# Config with /usr/bin/tr only in main, not in *
cat > "$OPENCLAW_CONFIG" << 'EOF'
{
  "version": 1,
  "defaults": {},
  "agents": {
    "*": {
      "allowlist": []
    },
    "main": {
      "allowlist": [
        {"pattern": "/usr/bin/tr", "id": "keep-me"}
      ]
    }
  }
}
EOF

bash "$HEALTH_CHECK" >/dev/null 2>&1

# /usr/bin/tr should be added to * allowlist
TR_IN_STAR=$(jq '[.agents["*"].allowlist[] | select(.pattern == "/usr/bin/tr")] | length' "$OPENCLAW_CONFIG")
# main should still have exactly 1 entry
MAIN_COUNT=$(jq '.agents["main"].allowlist | length' "$OPENCLAW_CONFIG")
MAIN_ID=$(jq -r '.agents["main"].allowlist[0].id' "$OPENCLAW_CONFIG")

if [ "$TR_IN_STAR" -ge 1 ] && [ "$MAIN_COUNT" = "1" ] && [ "$MAIN_ID" = "keep-me" ]; then
  pass
else
  fail "tr_in_star=$TR_IN_STAR main_count=$MAIN_COUNT main_id=$MAIN_ID"
fi
teardown_tmpdir

# =============================================
# TEST 12: per-agent overrides are removed (inherit defaults)
# =============================================
run_test "Per-agent security/ask/askFallback are removed"
setup_tmpdir

cat > "$OPENCLAW_CONFIG" << 'EOF'
{
  "version": 1,
  "defaults": {},
  "agents": {
    "*": {
      "allowlist": [],
      "security": "full",
      "ask": "always",
      "askFallback": "full"
    },
    "main": {
      "allowlist": [],
      "security": "full",
      "ask": "always",
      "askFallback": "full"
    }
  }
}
EOF

bash "$HEALTH_CHECK" >/dev/null 2>&1

STAR_SEC=$(jq 'has("agents") and (.agents["*"] | has("security"))' "$OPENCLAW_CONFIG")
STAR_ASK=$(jq 'has("agents") and (.agents["*"] | has("ask"))' "$OPENCLAW_CONFIG")
MAIN_SEC=$(jq 'has("agents") and (.agents["main"] | has("security"))' "$OPENCLAW_CONFIG")
MAIN_ASK=$(jq 'has("agents") and (.agents["main"] | has("ask"))' "$OPENCLAW_CONFIG")

if [ "$STAR_SEC" = "false" ] && [ "$STAR_ASK" = "false" ] && [ "$MAIN_SEC" = "false" ] && [ "$MAIN_ASK" = "false" ]; then
  pass
else
  fail "overrides remain: *.security=$STAR_SEC *.ask=$STAR_ASK main.security=$MAIN_SEC main.ask=$MAIN_ASK"
fi
teardown_tmpdir

# =============================================
# TEST 13: gateway restart command is called
# =============================================
run_test "Gateway restart command is executed"
setup_tmpdir
create_fixture_realistic

OUTPUT=$(bash "$HEALTH_CHECK" 2>&1)

if echo "$OUTPUT" | grep -q "gateway-restart-stub"; then
  pass
else
  fail "Gateway restart stub not found in output"
fi
teardown_tmpdir

# =============================================
# SUMMARY
# =============================================
echo ""
echo "==========================================="
echo "Results: $PASSED passed, $FAILED failed (total $TOTAL)"
echo "==========================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
