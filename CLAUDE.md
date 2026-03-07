# OpenClaw Exec-Approvals Health Check

## Documentation References

Always consult these docs when working on this project:

- Exec Approvals: https://docs.openclaw.ai/tools/exec-approvals
- Exec Tool: https://docs.openclaw.ai/tools/exec
- Tools Overview: https://docs.openclaw.ai/tools
- Skills: https://docs.openclaw.ai/cli/skills
- General Docs: https://docs.openclaw.ai/

## Project Overview

Shell script for safe health check and configuration of OpenClaw exec-approvals on VM.
Config path: `~/.openclaw/exec-approvals.json`
Dependency: `jq`

## Key Principles

- Always backup before changes
- Never break existing allowlist entries
- Offer rollback on errors
- Restart gateway after changes
