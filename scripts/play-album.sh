#!/usr/bin/env bash
set -euo pipefail

# Play a Navidrome album on THIS machine's speakers, streamed via the Subsonic
# API and played with mpv.
#
# Navidrome (music.home) serves the ~8k-file library remotely, so we stream
# rather than needing the files locally — the same way you already listen in
# Firefox. Credentials come from the voice-orchestrator .env (the same file
# speakers.sh reads for Home Assistant), never hardcoded here.
#
# Where it runs: playback is LOCAL — mpv outputs to whatever machine invokes
# this script (in practice the Framework, whose audio-out drives the desk
# speakers). music.home (10.0.50.47) is only the library/stream source and
# never plays audio itself. The morning-alarm systemd unit (see
# modules/morning-alarm.nix) is therefore wired on the Framework host only.
#
# Usage:
#   play-album.sh <albumId>
#   play-album.sh 'http://music.home/app/#/album/<albumId>/show'
#   play-album.sh                 # falls back to MORNING_ALBUM_ID from the .env
#
# The album ID is the same string that appears in the Navidrome web URL:
#   http://music.home/app/#/album/7xwaC1nzZ6ZyL9sN987JXS/show
#                                  \____________________/  <- this

ENV_FILE="${NAVIDROME_ENV:-$HOME/Repositories/projects/voice-assistant/orchestrator/.env}"

get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-; }

URL="${NAVIDROME_URL:-$(get NAVIDROME_URL)}"; URL="${URL:-http://music.home}"
URL="${URL%/}"
USER_NAME="${NAVIDROME_USER:-$(get NAVIDROME_USER)}"
PASS="${NAVIDROME_PASS:-$(get NAVIDROME_PASS)}"

if [ -z "$USER_NAME" ] || [ -z "$PASS" ]; then
  echo "play-album: NAVIDROME_USER / NAVIDROME_PASS not set in $ENV_FILE" >&2
  exit 1
fi

# --- resolve what to play: an album OR a playlist, given as a raw id or a full
#     Navidrome web URL (.../album/<id>/show or .../playlist/<id>/show). With no
#     argument, fall back to MORNING_ALBUM_ID from the .env (the morning pick).
arg="${1:-${MORNING_ALBUM_ID:-$(get MORNING_ALBUM_ID)}}"
if [ -z "$arg" ]; then
  echo "play-album: nothing to play (no id given and MORNING_ALBUM_ID unset)" >&2
  exit 2
fi
id="$(printf '%s' "$arg" | sed -E 's#.*/(album|playlist)/([^/?]+).*#\2#')"
case "$arg" in
  */playlist/*) kind=playlist ;;
  */album/*)    kind=album ;;
  *)            kind=auto ;;   # bare id: try album first, then playlist
esac

# --- Subsonic auth: token = md5(password + random salt) -----------------------
salt="$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
token="$(printf '%s%s' "$PASS" "$salt" | md5sum | cut -d' ' -f1)"
auth="u=${USER_NAME}&t=${token}&s=${salt}&v=1.16.1&c=play-album&f=json"

# --- fetch the track list, in order (album -> .song, playlist -> .entry) ------
query() { curl -s -m10 "${URL}/rest/$1.view?${auth}&id=${id}"; }
ok()    { [ "$(jq -r '."subsonic-response".status // "failed"' <<<"$1")" = "ok" ]; }

case "$kind" in
  album)    resp="$(query getAlbum)";    container=album ;;
  playlist) resp="$(query getPlaylist)"; container=playlist ;;
  auto)     resp="$(query getAlbum)"
            if ok "$resp"; then container=album
            else resp="$(query getPlaylist)"; container=playlist; fi ;;
esac

if ! ok "$resp"; then
  msg="$(jq -r '."subsonic-response".error.message // "unreachable / bad response"' <<<"$resp")"
  echo "play-album: Navidrome error: $msg" >&2
  exit 1
fi

songs_key=song; [ "$container" = playlist ] && songs_key=entry
name="$(jq -r ".\"subsonic-response\".${container}.name   // \"${container}\"" <<<"$resp")"
artist="$(jq -r ".\"subsonic-response\".${container}.artist // \"\"" <<<"$resp")"

# the song/entry list may be an array (normal) or a lone object; normalise it.
mapfile -t song_ids < <(jq -r \
  ".\"subsonic-response\".${container}.${songs_key} | if type==\"array\" then .[] else . end | .id" \
  <<<"$resp")

if [ "${#song_ids[@]}" -eq 0 ]; then
  echo "play-album: '$id' has no playable tracks" >&2
  exit 1
fi

echo "play-album: ▶ ${artist:+$artist — }$name (${#song_ids[@]} tracks)"

# --- stream URLs -> mpv -------------------------------------------------------
urls=()
for id in "${song_ids[@]}"; do
  urls+=("${URL}/rest/stream.view?${auth}&id=${id}")
done

# Interactive run (tty): keep mpv's keybindings for pause/next/quit.
# Headless run (systemd alarm): no terminal, and keep the journal quiet.
term_opts=()
[ -t 1 ] || term_opts=(--no-terminal --msg-level=all=warn)

exec mpv --no-video "${term_opts[@]}" "${urls[@]}"
