#!/usr/bin/env bash
set -euo pipefail

REPOS_DIR="/srv/git/repos"

# Use id_rsa (personal key, shared across machines) for homelab access.
# id_ed25519 is machine-specific and may not be authorized on the homelab yet.
IDENTITY_FILE="/home/aj/.ssh/id_rsa"
if [[ ! -f "$IDENTITY_FILE" ]]; then
  IDENTITY_FILE="/home/aj/.ssh/id_ed25519"
fi

SSH_OPTS=(
  -i "$IDENTITY_FILE"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile=/var/lib/git-seed/known_hosts
)

REPOS=(
  "arr-stack ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/arr-stack.git"
  "cooking ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/cooking.git"
  "dnsmasq-config ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/dnsmasq-config.git"
  "dotfiles ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/dotfiles.git"
  "infra-bootstrap ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/infra-bootstrap.git"
  "oreos-wireguard-config ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/oreos-wireguard-config.git"
  "mobius-anim ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/mobius-anim.git"
  "nixos-config ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/nixos-config.git"
  "nvim ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/nvim.git"
  "password-store ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git"
  "qwerty-services ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/qwerty-services.git"
  "raymer-homelab-docs ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/raymer-homelab-docs.git"
  "sauron-clipper-summary ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/sauron-clipper-summary.git"
  "shellscripts ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/shellscripts.git"
  "sweetpea-nginx-config ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/sweetpea-nginx-config.git"
  "sweetpea-reverse-proxy ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/sweetpea-reverse-proxy.git"
  "tftp-netboot-config ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/tftp-netboot-config.git"
  "tmux.conf ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/tmux.conf.git"
  "zettelkasten ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/zettelkasten.git"
)

echo "==> Seeding git repos into $REPOS_DIR"

sudo mkdir -p "$REPOS_DIR" /var/lib/git-seed
sudo chmod 700 /var/lib/git-seed
sudo chown -R git:git /srv/git || true
sudo chmod 2775 "$REPOS_DIR" || true

umask 002

failed=()

for entry in "${REPOS[@]}"; do
  read -r name url <<<"$entry"
  dest="$REPOS_DIR/$name.git"

  if sudo test -d "$dest"; then
    echo "--> Updating mirror: $name"
    sudo -u git git -c safe.directory="$dest" --git-dir="$dest" remote set-url origin "$url" || true
    if ! GIT_SSH_COMMAND="ssh ${SSH_OPTS[*]}" \
        sudo -u git git -c safe.directory="$dest" --git-dir="$dest" remote update --prune; then
      echo "WARN: failed to update $name — skipping."
      failed+=("$name")
      continue
    fi
  else
    echo "--> Cloning mirror: $name"
    tmp="$(mktemp -d)"

    if ! GIT_SSH_COMMAND="ssh ${SSH_OPTS[*]}" \
        git clone --mirror "$url" "$tmp/$name.git"; then
      echo "WARN: failed to clone $name — skipping."
      rm -rf "$tmp"
      failed+=("$name")
      continue
    fi

    sudo cp -a "$tmp/$name.git" "$dest"
    rm -rf "$tmp"
  fi

  sudo chown -R git:git "$dest"
  sudo chmod -R g+rwX "$dest"
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo ""
  echo "WARN: The following repos could not be mirrored (fix on homelab and rerun):"
  for r in "${failed[@]}"; do
    echo "  - $r"
  done
fi

echo "==> Done."
