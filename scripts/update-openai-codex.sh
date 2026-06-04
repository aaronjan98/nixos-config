#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PKG_FILE="${REPO_ROOT}/pkgs/openai-codex/default.nix"
PACKAGE_NAME='@openai/codex'

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
  scripts/update-openai-codex.sh [version] [--no-build]

Examples:
  scripts/update-openai-codex.sh
  scripts/update-openai-codex.sh 0.121.0
  scripts/update-openai-codex.sh --no-build

Behavior:
  - fetches the requested or latest Codex CLI release from npm
  - updates pkgs/openai-codex/default.nix version + source hash
  - optionally runs a Nix build to verify the package

This script updates tracked files only. Activate the result separately with:
  nrs
EOF
}

resolve_sri_hash() {
  local raw_hash="$1"

  if nix hash to-sri --type sha256 "$raw_hash" >/dev/null 2>&1; then
    nix hash to-sri --type sha256 "$raw_hash" 2>/dev/null
  else
    nix hash convert --hash-algo sha256 --to sri "$raw_hash"
  fi
}

update_default_nix() {
  local version="$1"
  local src_hash="$2"

  node - <<'NODE' "$PKG_FILE" "$version" "$src_hash"
const fs = require('fs');
const [file, version, srcHash] = process.argv.slice(2);
let text = fs.readFileSync(file, 'utf8');

text = text.replace(/version = "[^"]+";/, `version = "${version}";`);
text = text.replace(/hash = "[^"]+";/, `hash = "${srcHash}";`);

fs.writeFileSync(file, text);
NODE
}

main() {
  local version=""
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
        if [[ -n "$version" ]]; then
          warn "Only one version argument is supported"
          usage
          exit 1
        fi
        version="$1"
        ;;
    esac
    shift
  done

  require_cmd npm
  require_cmd nix
  require_cmd nix-prefetch-url
  require_cmd node

  if [[ ! -f "$PKG_FILE" ]]; then
    warn "Package file not found: $PKG_FILE"
    exit 1
  fi

  local flake_host
  flake_host="$(resolve_flake_host)"
  local build_target=".#nixosConfigurations.${flake_host}.config.system.build.toplevel"

  if [[ -z "$version" ]]; then
    log "Resolving latest Codex version from npm"
    version="$(npm view "$PACKAGE_NAME" version)"
  fi

  local tarball_url="https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz"

  log "Computing source hash for Codex ${version}"
  local src_hash_raw
  src_hash_raw="$(nix-prefetch-url --unpack "$tarball_url")"

  local src_hash_sri
  src_hash_sri="$(resolve_sri_hash "$src_hash_raw")"

  log "Updating tracked Codex package file"
  update_default_nix "$version" "$src_hash_sri"

  if [[ "$run_build" -eq 1 ]]; then
    log "Building ${flake_host} NixOS system to verify the update"
    nix build "$build_target" --impure --extra-experimental-features 'nix-command flakes' --option warn-dirty false
  else
    log "Skipping verification build (--no-build)"
  fi

  log "Codex update file is ready"
  printf '\nUpdated file:\n'
  printf '  %s\n' "$PKG_FILE"
  printf '\nNext steps:\n'
  printf '  1. Review the diff\n'
  printf '  2. Run: nrs\n'
  printf '     (explicit: sudo nixos-rebuild switch --flake ~/nixos-config#%s)\n' "$flake_host"
  printf '  3. Verify: codex --version\n'
}

main "$@"
