#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Updating from GitHub..."
git checkout openclaw-exec-approvals-health-check.sh 2>/dev/null || true
git pull

chmod +x openclaw-exec-approvals-health-check.sh

echo ""
echo "Running health check..."
./openclaw-exec-approvals-health-check.sh --all
