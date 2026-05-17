#!/usr/bin/env bash
# notify.sh — borgmatic hook that sends notifications via dispatcher
#
# Usage: notify.sh <success|error>

set -euo pipefail

DISPATCHER_URL="${DISPATCHER_URL:-http://100.69.1.1:5001}"
STATUS="${1:-unknown}"
HOSTNAME="$(hostname -s)"

if [ -z "$HOSTNAME" ]; then
    HOSTNAME="homelab-vps"
fi

if [ "$STATUS" = "success" ]; then
    BODY="✅ Backup completed successfully on \`${HOSTNAME}\`"
    HTML="<b>✅ Backup completed successfully</b> on <code>${HOSTNAME}</code>"
else
    BODY="💥 Backup failed on \`${HOSTNAME}\`"
    HTML="<b>💥 Backup failed</b> on <code>${HOSTNAME}</code>"
fi

curl -fS -X POST \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg body "$BODY" --arg html "$HTML" '{"body":$body,"html":$html}')" \
  "${DISPATCHER_URL}/notify?service=borgmatic" \
  || echo "Warning: failed to send notification via dispatcher" >&2
