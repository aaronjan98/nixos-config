#!/usr/bin/env sh
set -eu

for bat in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
  if [ -r "$bat/capacity" ]; then
    cap="$(cat "$bat/capacity")"
    stat=""
    if [ -r "$bat/status" ]; then
      s="$(cat "$bat/status" || true)"
      case "$s" in
        Charging) stat="+" ;;
        Discharging) stat="-" ;;
        Full) stat="=" ;;
        *) stat="" ;;
      esac
    fi
    printf "%s%%%s" "$cap" "$stat"
    exit 0
  fi
done

printf "?"

