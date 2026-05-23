#!/usr/bin/env bash
# Wrapper around rkhunter that sends a failure notification via dispatcher.

set -euo pipefail

DISPATCHER_URL="${DISPATCHER_URL:-http://100.69.1.1:5001}"
HOSTNAME="$(hostname -s 2>/dev/null || true)"
RKHUNTER_BIN="${RKHUNTER_BIN:-/usr/bin/rkhunter}"

if [ -z "$HOSTNAME" ]; then
    HOSTNAME="homelab-vps"
fi

notify_failure() {
    local exit_code="$1"
    local output_file="$2"
    local details html details_html payload

    details="$(tail -n 60 "$output_file" 2>/dev/null || true)"
    if [ -z "$details" ]; then
        details="No output captured from rkhunter."
    fi

    html_escape() {
        sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
    }

    details_html="$(printf '%s' "$details" | html_escape)"

    html="<b>🚨 rkhunter scan failed</b> on <code>${HOSTNAME}</code><br>"
    html+="Exit code: <b>${exit_code}</b><br><br>"
    html+="<b>Last output lines:</b><br><pre>${details_html}</pre>"

    payload="$(python3 -c 'import json,sys; print(json.dumps({"body": sys.argv[1], "html": sys.argv[2]}))' \
      "🚨 rkhunter scan failed on ${HOSTNAME} (exit ${exit_code})\n\nLast output lines:\n${details}" \
      "$html")"

    curl -fsS -X POST \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${DISPATCHER_URL}/notify" \
      || echo "Warning: failed to send rkhunter failure notification" >&2
}

main() {
    local output_file="" exit_code

    output_file="$(mktemp)"
    trap 'if [ -n "${output_file:-}" ]; then rm -f "$output_file"; fi' EXIT

    set +e
    "$RKHUNTER_BIN" --check --cronjob --quiet --report-warnings-only --skip-keypress >"$output_file" 2>&1
    exit_code=$?
    set -e

    cat "$output_file"

    if [ "$exit_code" -gt 1 ]; then
        notify_failure "$exit_code" "$output_file"
        exit "$exit_code"
    fi

    if [ "$exit_code" -eq 1 ]; then
        echo "rkhunter completed with warnings (exit 1); treating as non-fatal." >&2
    fi
}

main "$@"
