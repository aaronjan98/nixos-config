#!/usr/bin/env bash
set -euo pipefail

NAS_HOST="${NAS_HOST:-aj@qwerty.home}"
NAS_BASE="${NAS_BASE:-/mnt/storage/distfiles}"
LOCAL_BASE="${LOCAL_BASE:-/var/lib/distfiles}"

# If arguments are provided, sync only those subdirs (e.g. wolfram jetbrains).
FILTERS=("$@")

SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
)

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

sync_one() {
  local subdir="$1"
  echo "==> Syncing ${subdir} into staging area..."
  mkdir -p "${tmpdir}/${subdir}"

  rsync -avP --delete \
    -e "ssh ${SSH_OPTS[*]}" \
    "${NAS_HOST}:${NAS_BASE}/${subdir}/" \
    "${tmpdir}/${subdir}/"

  echo "==> Installing ${subdir} into ${LOCAL_BASE} (requires sudo)..."
  sudo install -d -m 0755 "${LOCAL_BASE}/${subdir}"
  sudo rsync -avP --delete "${tmpdir}/${subdir}/" "${LOCAL_BASE}/${subdir}/"
}

sync_all() {
  echo "==> Listing remote distfiles directories..."
  mapfile -t remote_dirs < <(
    ssh "${SSH_OPTS[@]}" "${NAS_HOST}" \
      "find '${NAS_BASE}' -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort"
  )

  if [[ "${#remote_dirs[@]}" -eq 0 ]]; then
    echo "No remote directories found under ${NAS_BASE}."
    exit 1
  fi

  for d in "${remote_dirs[@]}"; do
    sync_one "${d}"
  done
}

main() {
  # Quick preflight: show which key/config SSH will use *as your user*.
  echo "==> SSH preflight (as $(whoami)):"
  ssh -G "${NAS_HOST}" 2>/dev/null | awk '
    $1=="user"||$1=="hostname"||$1=="identityfile"||$1=="identitiesonly"||$1=="proxyjump" {print "    " $0}
  ' || true

  if [[ "${#FILTERS[@]}" -gt 0 ]]; then
    for f in "${FILTERS[@]}"; do
      sync_one "${f}"
    done
  else
    sync_all
  fi

  echo "==> Done. Local distfiles at: ${LOCAL_BASE}"
}

main "$@"

