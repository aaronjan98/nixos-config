#!/usr/bin/env bash
set -euo pipefail

# backup-secrets.sh — save SSH files from ~/.ssh/ into pass.
#
# Inverse of restore-secrets.sh. Run manually after editing SSH material
# (e.g. adding a new host to ~/.ssh/config).
#
# Backs up only files in the known list that exist locally. Encrypts directly
# via gpg (no interactive prompts) and makes a single git commit at the end.
# Does NOT push — run `pass git push` when ready.
#
# Usage: backup-secrets.sh

_pass_machine_slug() {
    case "$(hostname)" in
        nixos) echo "thinkpad-t14-nixos" ;;
        *)     echo "$(hostname)" ;;
    esac
}

PASS_DIR="${HOME}/.password-store"
SSH_DIR="${HOME}/.ssh"
SLUG="$(_pass_machine_slug)"
PASS_SSH_PREFIX="laptop/${SLUG}/ssh"
GPG_KEY_ID="$(cat "${PASS_DIR}/.gpg-id")"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || { warn "Required command not found: $1"; exit 1; }
}

backup_ssh_file() {
    local name="$1"
    local src="${SSH_DIR}/${name}"
    local dest="${PASS_DIR}/${PASS_SSH_PREFIX}/${name}.gpg"

    mkdir -p "$(dirname "${dest}")"
    gpg --batch --yes --recipient "${GPG_KEY_ID}" --encrypt --output "${dest}" < "${src}"
    log "Backed up: ~/.ssh/${name} → pass:${PASS_SSH_PREFIX}/${name}"
}

main() {
    require_cmd gpg
    require_cmd pass

    [[ -f "${PASS_DIR}/.gpg-id" ]] || { warn "Pass store not found at ${PASS_DIR}"; exit 1; }

    log "Backing up SSH files → pass prefix: ${PASS_SSH_PREFIX}"
    log "GPG key: ${GPG_KEY_ID}"

    local names=(
        authorized_keys
        calKeyPair.pem
        config
        id_ed25519.fedora
        id_ed25519.fedora.pub
        id_ed25519.jetra
        id_ed25519.jetra.pub
        id_ed25519.kamatera
        id_ed25519.kamatera.pub
        id_ed25519.linode
        id_ed25519.linode.pub
        id_ed25519.oreos
        id_ed25519.oreos.pub
        id_oracle.key
        id_oracle.key.pub
        id_rsa
        id_rsa.pub
        known_hosts
        known_hosts.old
    )

    local backed_up=0
    local name
    for name in "${names[@]}"; do
        if [[ -f "${SSH_DIR}/${name}" ]]; then
            backup_ssh_file "${name}"
            backed_up=$((backed_up + 1))
        fi
    done

    if [[ "${backed_up}" -eq 0 ]]; then
        warn "No SSH files found to back up in ${SSH_DIR}"
        exit 1
    fi

    log "Committing ${backed_up} file(s) to pass git..."
    pass git add -A
    if [[ -n "$(pass git status --porcelain 2>/dev/null)" ]]; then
        pass git commit -m "backup-secrets: update ${PASS_SSH_PREFIX} from $(hostname)"
        log "Done. Push when ready: pass git push"
    else
        log "No changes — pass already up to date."
    fi
}

main "$@"
