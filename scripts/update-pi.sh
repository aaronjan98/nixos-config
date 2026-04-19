#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PKG_FILE="${REPO_ROOT}/pkgs/pi/default.nix"
LOCK_FILE="${REPO_ROOT}/pkgs/pi/package-lock.json"
BUILD_TARGET='.#nixosConfigurations.thinkpad-t14.config.system.build.toplevel'
PACKAGE_NAME='@mariozechner/pi-coding-agent'

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

usage() {
  cat <<'EOF'
Usage:
  scripts/update-pi.sh [version] [--no-build]

Examples:
  scripts/update-pi.sh
  scripts/update-pi.sh 0.67.68
  scripts/update-pi.sh --no-build

Behavior:
  - fetches the requested or latest Pi release from npm
  - regenerates pkgs/pi/package-lock.json
  - updates pkgs/pi/default.nix version + hashes
  - optionally runs a Nix build to verify the package

This script updates tracked files only. Activate the result separately with:
  sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14
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
  local npm_hash="$3"

  node - <<'NODE' "$PKG_FILE" "$version" "$src_hash" "$npm_hash"
const fs = require('fs');
const [file, version, srcHash, npmHash] = process.argv.slice(2);
let text = fs.readFileSync(file, 'utf8');

text = text.replace(/version = "[^"]+";/, `version = "${version}";`);
text = text.replace(/hash = "[^"]+";/, `hash = "${srcHash}";`);
text = text.replace(/npmDepsHash = "[^"]+";/, `npmDepsHash = "${npmHash}";`);

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

  require_cmd curl
  require_cmd tar
  require_cmd npm
  require_cmd node
  require_cmd nix
  require_cmd nix-prefetch-url

  if [[ ! -f "$PKG_FILE" ]]; then
    warn "Package file not found: $PKG_FILE"
    exit 1
  fi

  if [[ -z "$version" ]]; then
    log "Resolving latest Pi version from npm"
    version="$(npm view "$PACKAGE_NAME" version)"
  fi

  log "Updating Pi package to ${version}"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  local tarball_url="https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz"
  local tarball_path="${tmp_dir}/pi-coding-agent-${version}.tgz"
  local source_dir="${tmp_dir}/src"

  log "Downloading npm tarball"
  curl -L "$tarball_url" -o "$tarball_path"

  mkdir -p "$source_dir"
  tar -xzf "$tarball_path" -C "$source_dir"

  log "Regenerating package-lock.json"
  cp -r "$source_dir/package/." "$tmp_dir/"
  (
    cd "$tmp_dir"
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund --legacy-peer-deps
  )

  log "Computing source hash"
  local src_hash_raw
  src_hash_raw="$(nix-prefetch-url --unpack "$tarball_url")"

  local src_hash_sri
  src_hash_sri="$(resolve_sri_hash "$src_hash_raw")"

  log "Computing npm dependency hash"
  local npm_deps_hash
  npm_deps_hash="$(nix shell nixpkgs#prefetch-npm-deps -c prefetch-npm-deps "$tmp_dir/package-lock.json")"

  log "Updating tracked Pi package files"
  cp "$tmp_dir/package-lock.json" "$LOCK_FILE"
  update_default_nix "$version" "$src_hash_sri" "$npm_deps_hash"

  if [[ "$run_build" -eq 1 ]]; then
    log "Building NixOS system to verify the update"
    nix build "$BUILD_TARGET" --impure --extra-experimental-features 'nix-command flakes' --option warn-dirty false
  else
    log "Skipping verification build (--no-build)"
  fi

  log "Pi update files are ready"
  printf '\nUpdated files:\n'
  printf '  %s\n' "$PKG_FILE"
  printf '  %s\n' "$LOCK_FILE"
  printf '\nNext steps:\n'
  printf '  1. Review the diff\n'
  printf '  2. Run: sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14\n'
  printf '  3. Verify: pi --version\n'
}

main "$@"
