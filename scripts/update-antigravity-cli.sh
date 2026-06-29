#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PKG_FILE="${REPO_ROOT}/pkgs/antigravity-cli/default.nix"
MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "Required command not found: $1"
    exit 1
  }
}

resolve_flake_host() {
  local host="${NIXOS_FLAKE_HOST:-$(hostname)}"

  case "$host" in
    nixos) echo "thinkpad-t14" ;;
    *) echo "$host" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  scripts/update-antigravity-cli.sh [--no-build]

Examples:
  scripts/update-antigravity-cli.sh
  scripts/update-antigravity-cli.sh --no-build

Behavior:
  - fetches the latest Antigravity CLI version from the upstream manifest
  - downloads the Linux x64 tarball and computes its Nix hash
  - updates pkgs/antigravity-cli/default.nix with the new version, URL, and hash
  - optionally runs a Nix build to verify the package

This script updates tracked files only. Activate the result separately with:
  nrs
EOF
}

update_default_nix() {
  local version="$1"
  local url="$2"
  local hash="$3"

  node - <<'NODE' "$PKG_FILE" "$version" "$url" "$hash"
const fs = require('fs');
const [file, version, url, hash] = process.argv.slice(2);
let text = fs.readFileSync(file, 'utf8');

text = text.replace(/version = "[^"]+";/, `version = "${version}";`);
text = text.replace(/url = "[^"]+";/, `url = "${url}";`);
text = text.replace(/hash = "[^"]+";/, `hash = "${hash}";`);

fs.writeFileSync(file, text);
NODE
}

main() {
  local run_build=1

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-build)
        run_build=0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        warn "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done

  require_cmd curl
  require_cmd jq
  require_cmd nix
  require_cmd node

  if [[ ! -f "$PKG_FILE" ]]; then
    warn "Package file not found: $PKG_FILE"
    exit 1
  fi

  local flake_host
  flake_host="$(resolve_flake_host)"
  local build_target=".#nixosConfigurations.${flake_host}.config.system.build.toplevel"

  log "Fetching Antigravity CLI manifest"
  local manifest
  manifest="$(curl -fsSL "$MANIFEST_URL")"

  local version url
  version="$(echo "$manifest" | jq -r '.version')"
  url="$(echo "$manifest" | jq -r '.url')"

  log "Latest version: ${version}"

  local tmpfile
  tmpfile="$(mktemp --suffix=.tar.gz)"
  trap "rm -f $tmpfile" EXIT

  log "Downloading tarball from ${url}"
  curl -fsSL "$url" -o "$tmpfile"

  log "Computing Nix hash"
  local hash
  hash="$(nix hash file "$tmpfile")"

  log "Updating tracked package file"
  update_default_nix "$version" "$url" "$hash"

  if [[ "$run_build" -eq 1 ]]; then
    log "Building ${flake_host} NixOS system to verify the update"
    nix build "$build_target" --impure --extra-experimental-features 'nix-command flakes' --option warn-dirty false
  else
    log "Skipping verification build (--no-build)"
  fi

  log "Antigravity CLI update is ready"
  printf '\nUpdated to version: %s\n' "$version"
  printf 'Updated file:\n'
  printf '  %s\n' "$PKG_FILE"
  printf '\nNext steps:\n'
  printf '  1. Review the diff\n'
  printf '  2. Run: nrs\n'
  printf '     (explicit: sudo nixos-rebuild switch --flake ~/nixos-config#%s)\n' "$flake_host"
  printf '  3. Verify: agy --version\n'
}

main "$@"
