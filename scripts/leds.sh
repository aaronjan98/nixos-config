#!/usr/bin/env bash
set -euo pipefail

# Control the desk LED strip (300 WS2812B LEDs on an ESP32 at desk-leds.home).
#
# The strip is NOT in Home Assistant — it's a standalone ESP32 exposing a tiny
# HTTP API at /set (the same endpoint the voice-orchestrator's desk_leds tool
# uses). There's no auth, so this script just curls it directly. Host defaults to
# desk-leds.home; override with DESK_LEDS_HOST.
#
# Usage:
#   leds                     show current on/off state (default)
#   leds on | off | toggle   power the strip
#   leds anim <name>         demoreel rainbow cylon fire pacifica pride scratch
#                            swell fireworks laser waves   (audio ones need mic on)
#   leds bright <0-255>      brightness
#   leds speed <1-10>        animation speed
#   leds glitter <mode>      off twinkle drizzle rain snow thunder
#   leds mic on|off          audio-reactive mode

HOST="${DESK_LEDS_HOST:-desk-leds.home}"
BASE="http://$HOST"

GLITTER_MODES=(off twinkle drizzle rain snow thunder)

set_param() {  # set_param key value
  curl -s -m8 -G "$BASE/set" --data-urlencode "$1=$2" >/dev/null
}

power_state() {  # -> on | off | unknown
  curl -s -m6 "$BASE/" | grep -oE 'LEDs: (ON|OFF)' | head -1 | awk '{print tolower($2)}'
}

glitter_index() {  # name -> index, or empty
  local i
  for i in "${!GLITTER_MODES[@]}"; do
    [ "${GLITTER_MODES[$i]}" = "$1" ] && { echo "$i"; return; }
  done
}

action="${1:-status}"
case "$action" in
  on)     set_param power 1; echo "leds: on" ;;
  off)    set_param power 0; echo "leds: off" ;;
  toggle) if [ "$(power_state)" = "on" ]; then set_param power 0; else set_param power 1; fi
          sleep 1; echo "leds: $(power_state)" ;;
  status) echo "leds: $(power_state)" ;;
  anim)   [ -n "${2:-}" ] || { echo "usage: leds anim <name>" >&2; exit 2; }
          set_param anim "$2"; echo "leds: anim=$2" ;;
  bright) [ -n "${2:-}" ] || { echo "usage: leds bright <0-255>" >&2; exit 2; }
          set_param bright "$2"; echo "leds: bright=$2" ;;
  speed)  [ -n "${2:-}" ] || { echo "usage: leds speed <1-10>" >&2; exit 2; }
          set_param speed "$2"; echo "leds: speed=$2" ;;
  glitter)
          idx="$(glitter_index "${2:-}")"
          [ -n "$idx" ] || { echo "usage: leds glitter {${GLITTER_MODES[*]}}" >&2; exit 2; }
          set_param glitter "$idx"; echo "leds: glitter=$2" ;;
  mic)    case "${2:-}" in on) v=1 ;; off) v=0 ;; *) echo "usage: leds mic on|off" >&2; exit 2 ;; esac
          set_param mic "$v"; echo "leds: mic=$2" ;;
  *) echo "usage: $(basename "$0") [on|off|toggle|status|anim <n>|bright <n>|speed <n>|glitter <m>|mic on|off]" >&2
     exit 2 ;;
esac
