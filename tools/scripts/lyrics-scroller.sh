#!/usr/bin/env bash
# Terminal karaoke-style scrolling lyrics for whatever is currently playing
# via MPRIS (e.g. Navidrome's web player in Firefox/Chrome). Reads live
# position from playerctl and lyrics text from Navidrome's OpenSubsonic
# getLyricsBySongId endpoint -- no local music files touched.
#
# Config: export NAVIDROME_USER / NAVIDROME_PASS, or drop them in
#   ~/.config/lyrics-scroller/env   (untracked, not part of this repo)
# as:
#   NAVIDROME_USER=aj
#   NAVIDROME_PASS=...
set -uo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/lyrics-scroller/env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

NAVIDROME_URL="${NAVIDROME_URL:-https://music.janovitch.com/rest}"
NAVIDROME_SALT="${NAVIDROME_SALT:-abc123}"
NAVIDROME_USER="${NAVIDROME_USER:?set NAVIDROME_USER (env or $CONFIG_FILE)}"
NAVIDROME_PASS="${NAVIDROME_PASS:?set NAVIDROME_PASS (env or $CONFIG_FILE)}"
API_VERSION="1.16.1"
CONTEXT_LINES="${LYRICS_CONTEXT_LINES:-4}"
POLL_INTERVAL="${LYRICS_POLL_INTERVAL:-0.3}"
OFFSET_STEP_MS="${LYRICS_OFFSET_STEP_MS:-100}"
DELIM=$'\x1f'

declare -a STARTS=()
declare -a TEXTS=()
UNSYNCED=0
LAST_TRACK_KEY=""
LAST_POS_S=0
OFFSET_MS="${LYRICS_OFFSET_MS:-0}"
LAST_KEY_DEBUG=""

token() { printf '%s' "${NAVIDROME_PASS}${NAVIDROME_SALT}" | md5sum | cut -d' ' -f1; }
api_params() {
  printf 'u=%s&t=%s&s=%s&v=%s&c=lyrics-scroller&f=json' \
    "$NAVIDROME_USER" "$(token)" "$NAVIDROME_SALT" "$API_VERSION"
}

find_player() {
  local p
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if [[ "$(playerctl -p "$p" status 2>/dev/null)" == "Playing" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done < <(playerctl -l 2>/dev/null)
  # nothing actively playing -- fall back to any player that exists (paused)
  playerctl -l 2>/dev/null | head -1
}

fetch_synced_lyrics() {
  local title="$1" artist="$2" id
  id=$(curl -sG "${NAVIDROME_URL}/search3" --data-urlencode "query=${title}" \
        -d "$(api_params)" \
      | jq -r --arg artist "$artist" \
        '.["subsonic-response"].searchResult3.song[]? | select(.artist == $artist) | .id' \
      | head -1)
  if [[ -z "$id" ]]; then
    id=$(curl -sG "${NAVIDROME_URL}/search3" --data-urlencode "query=${title}" \
          -d "$(api_params)" \
        | jq -r '.["subsonic-response"].searchResult3.song[0].id // empty')
  fi
  [[ -z "$id" ]] && return 1
  curl -s "${NAVIDROME_URL}/getLyricsBySongId?id=${id}&$(api_params)" \
    | jq -c '.["subsonic-response"].lyricsList.structuredLyrics[0].line // empty'
}

fetch_plain_lyrics() {
  local title="$1" artist="$2"
  curl -sG "${NAVIDROME_URL}/getLyrics" \
    --data-urlencode "artist=${artist}" --data-urlencode "title=${title}" \
    -d "$(api_params)" \
    | jq -r '.["subsonic-response"].lyrics.value // empty'
}

load_lyrics_for_track() {
  local title="$1" artist="$2" lines_json
  STARTS=(); TEXTS=(); UNSYNCED=0
  lines_json=$(fetch_synced_lyrics "$title" "$artist")
  if [[ -n "$lines_json" && "$lines_json" != "null" && "$lines_json" != "[]" ]]; then
    mapfile -t STARTS < <(jq -r '.[].start' <<<"$lines_json")
    mapfile -t TEXTS  < <(jq -r '.[].value' <<<"$lines_json")
    return
  fi
  local plain
  plain=$(fetch_plain_lyrics "$title" "$artist")
  if [[ -n "$plain" ]]; then
    UNSYNCED=1
    mapfile -t TEXTS <<<"$plain"
  else
    TEXTS=("(no lyrics found)")
  fi
}

find_current_index() {
  local pos_ms="$1" idx=-1 i
  for i in "${!STARTS[@]}"; do
    if (( STARTS[i] <= pos_ms )); then
      idx=$i
    else
      break
    fi
  done
  printf '%d' "$idx"
}

render() {
  local idx="$1" title="$2" artist="$3" status="$4" pos_ms="$5" i line start end last next_in=""
  if (( idx + 1 < ${#STARTS[@]} )); then
    next_in=$(awk -v a="${STARTS[idx+1]}" -v b="$pos_ms" 'BEGIN{printf "%.1f", (a-b)/1000}')
  fi
  printf '\033[H\033[J'
  printf '\033[1m%s\033[0m \033[2m—\033[0m %s  \033[2m[%s | offset %+dms | next line in %ss | last key: %s]\033[0m\n\n' \
    "$title" "$artist" "$status" "$OFFSET_MS" "${next_in:-?}" "${LAST_KEY_DEBUG:-none}"

  if (( UNSYNCED )); then
    printf '\033[2m(unsynced lyrics -- no timing data)\033[0m\n\n'
    printf '%s\n' "${TEXTS[@]}"
    return
  fi

  last=$(( ${#TEXTS[@]} - 1 ))
  if (( last < 0 )); then
    echo "(no lyrics found)"
    return
  fi
  if (( idx < 0 )); then
    echo "(instrumental intro...)"
    echo
  fi
  start=$(( idx - CONTEXT_LINES )); (( start < 0 )) && start=0
  end=$(( idx + CONTEXT_LINES )); (( end > last )) && end=$last
  for (( i=start; i<=end; i++ )); do
    line="${TEXTS[i]:-}"
    [[ -z "$line" ]] && line=" "
    if (( i == idx )); then
      printf '\033[1;36m> %s\033[0m\n' "$line"
    else
      printf '  \033[2m%s\033[0m\n' "$line"
    fi
  done
}

ORIG_STTY=$(stty -g 2>/dev/null || true)
cleanup() {
  [[ -n "$ORIG_STTY" ]] && stty "$ORIG_STTY" 2>/dev/null
  tput cnorm 2>/dev/null
  printf '\033[H\033[J'
  exit 0
}
trap cleanup INT TERM EXIT

tput civis 2>/dev/null
[[ -n "$ORIG_STTY" ]] && stty -icanon -echo min 0 time 0 2>/dev/null

while true; do
  player=$(find_player)
  if [[ -z "$player" ]]; then
    printf '\033[H\033[J\033[2mNo MPRIS player found. Waiting...\033[0m\n'
    sleep 2
    continue
  fi

  meta=$(playerctl -p "$player" metadata --format "{{title}}${DELIM}{{artist}}" 2>/dev/null)
  IFS="$DELIM" read -r title artist <<<"$meta"
  if [[ -z "$title" ]]; then
    read -r -t "$POLL_INTERVAL" -n 1 key 2>/dev/null || true
    continue
  fi

  track_key="${title}${DELIM}${artist}"
  if [[ "$track_key" != "$LAST_TRACK_KEY" ]]; then
    LAST_TRACK_KEY="$track_key"
    load_lyrics_for_track "$title" "$artist"
  fi

  status=$(playerctl -p "$player" status 2>/dev/null)
  if [[ "$status" == "Playing" ]]; then
    pos_s=$(playerctl -p "$player" position 2>/dev/null || echo "$LAST_POS_S")
    LAST_POS_S="$pos_s"
  else
    # Firefox's MPRIS position keeps climbing on its own while paused --
    # freeze at the last known position instead of trusting it.
    pos_s="$LAST_POS_S"
  fi
  pos_ms=$(awk -v p="$pos_s" -v o="$OFFSET_MS" 'BEGIN{printf "%d", p*1000+o}')
  idx=$(find_current_index "$pos_ms")

  render "$idx" "$title" "$artist" "$status" "$pos_ms"

  key=""
  read -r -t "$POLL_INTERVAL" -n 1 key 2>/dev/null || true
  if [[ -n "$key" ]]; then
    if [[ "$key" == $'\x1b' ]]; then
      # Arrow keys send ESC [ C/D (or ESC O C/D in application-cursor-key
      # mode) -- read the remaining bytes to tell left from right.
      key2=""; key3=""
      read -r -t 0.2 -n 1 key2 2>/dev/null || true
      read -r -t 0.2 -n 1 key3 2>/dev/null || true
      LAST_KEY_DEBUG="ESC $(printf '%q' "$key2") $(printf '%q' "$key3")"
      case "$key3" in
        C) OFFSET_MS=$(( OFFSET_MS + OFFSET_STEP_MS ));;  # right arrow -> earlier
        D) OFFSET_MS=$(( OFFSET_MS - OFFSET_STEP_MS ));;  # left arrow -> later
      esac
    else
      LAST_KEY_DEBUG="$(printf '%q' "$key")"
      case "$key" in
        '[') OFFSET_MS=$(( OFFSET_MS - OFFSET_STEP_MS ));;
        ']') OFFSET_MS=$(( OFFSET_MS + OFFSET_STEP_MS ));;
        r|R) OFFSET_MS=0;;
        q|Q) cleanup;;
      esac
    fi
  fi
done
