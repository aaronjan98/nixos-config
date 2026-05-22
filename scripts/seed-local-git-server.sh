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

BASE="ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos"
REPOS=(
  "Math-450A-Class-Notes ${BASE}/Math-450A-Class-Notes.git"
  "Prob-Stats-Notes ${BASE}/Prob-Stats-Notes.git"
  "arr-stack ${BASE}/arr-stack.git"
  "claude-display ${BASE}/claude-display.git"
  "clipper-video-summary-client ${BASE}/clipper-video-summary-client.git"
  "cooking ${BASE}/cooking.git"
  "diff_eqns_dyn_sys_jupyter_notebook ${BASE}/diff_eqns_dyn_sys_jupyter_notebook.git"
  "dnsmasq-config ${BASE}/dnsmasq-config.git"
  "dotfiles ${BASE}/dotfiles.git"
  "ds_home ${BASE}/ds_home.git"
  "egt-graph-cooperation ${BASE}/egt-graph-cooperation.git"
  "infra-bootstrap ${BASE}/infra-bootstrap.git"
  "mobius-anim ${BASE}/mobius-anim.git"
  "nixos-config ${BASE}/nixos-config.git"
  "nvim ${BASE}/nvim.git"
  "oreos-wireguard-config ${BASE}/oreos-wireguard-config.git"
  "password-store ${BASE}/password-store.git"
  "qwerty-services ${BASE}/qwerty-services.git"
  "raymer-homelab-docs ${BASE}/raymer-homelab-docs.git"
  "sauron-clipper-summary ${BASE}/sauron-clipper-summary.git"
  "scientific_computing ${BASE}/scientific_computing.git"
  "shellscripts ${BASE}/shellscripts.git"
  "sweetpea-nginx-config ${BASE}/sweetpea-nginx-config.git"
  "sweetpea-reverse-proxy ${BASE}/sweetpea-reverse-proxy.git"
  "tftp-netboot-config ${BASE}/tftp-netboot-config.git"
  "tmux.conf ${BASE}/tmux.conf.git"
  "trad-mus-research-paper ${BASE}/trad-mus-research-paper.git"
  "zettelkasten ${BASE}/zettelkasten.git"
)

echo "==> Seeding git repos into $REPOS_DIR"

sudo mkdir -p "$REPOS_DIR"
sudo install -d -m 700 -o aj -g users /var/lib/git-seed
sudo chown -R git:git /srv/git || true
sudo chmod 2775 "$REPOS_DIR" || true

umask 002

failed=()

for entry in "${REPOS[@]}"; do
  read -r name url <<<"$entry"
  dest="$REPOS_DIR/$name.git"

  if sudo test -d "$dest"; then
    echo "--> Updating mirror: $name"
    git -c safe.directory="$dest" --git-dir="$dest" remote set-url origin "$url" || true
    if ! GIT_SSH_COMMAND="ssh ${SSH_OPTS[*]}" \
        git -c safe.directory="$dest" --git-dir="$dest" remote update --prune; then
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
