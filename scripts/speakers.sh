#!/usr/bin/env bash
set -euo pipefail

# Turn the receiver / desk speakers on or off.
#
# The speaker plug is a Kasa KP125M whose firmware uses TPAP encryption, which
# python-kasa (and the `kasa` CLI) cannot speak. It is controlled locally through
# Home Assistant's Matter integration instead, so this script just calls HA's REST
# API. HA_URL/HA_TOKEN are read from the voice-orchestrator .env (not hardcoded).
#
# Usage: speakers [on|off|toggle|status]   (default: status)

ENV_FILE="${SPEAKERS_ENV:-$HOME/Repositories/projects/voice-assistant/orchestrator/.env}"
ENTITY="${SPEAKER_SWITCH_ENTITY:-switch.kasa_smart_wi_fi_plug}"

get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-; }
HA_URL="$(get HA_URL)"; HA_URL="${HA_URL:-http://localhost:8123}"
HA_TOKEN="$(get HA_TOKEN)"

if [ -z "$HA_TOKEN" ]; then
  echo "speakers: no HA_TOKEN found in $ENV_FILE" >&2
  exit 1
fi

auth=(-H "Authorization: Bearer $HA_TOKEN")

state() {
  curl -s -m6 "${auth[@]}" "$HA_URL/api/states/$ENTITY" \
    | grep -oE '"state":"[^"]*"' | head -1 | cut -d'"' -f4
}

switch() {  # $1 = on|off
  curl -s -m10 -X POST "${auth[@]}" -H 'Content-Type: application/json' \
    "$HA_URL/api/services/switch/turn_$1" \
    -d "{\"entity_id\":\"$ENTITY\"}" >/dev/null
}

action="${1:-status}"
case "$action" in
  on|off) switch "$action"; sleep 1; echo "speakers: $(state)" ;;
  toggle) [ "$(state)" = "on" ] && switch off || switch on; sleep 1; echo "speakers: $(state)" ;;
  status) echo "speakers: $(state)" ;;
  *) echo "usage: $(basename "$0") [on|off|toggle|status]" >&2; exit 2 ;;
esac
