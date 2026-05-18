#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: new-homelab-repo <name> [--public]"
    echo ""
    echo "Creates a bare repo on sweetpea, a matching Forgejo repo, and wires"
    echo "up the post-receive hook so pushes to 'home' auto-sync to Forgejo."
    echo ""
    echo "Defaults to private. Pass --public for a public Forgejo repo."
    exit 1
}

[[ $# -lt 1 ]] && usage

NAME="$1"
VISIBILITY="${2:---private}"
FORGEJO_USER="aj"
FORGEJO_URL="https://git.aaronjanovitch.com"
REPOS_DIR="/srv/git/repos"

: "${FORGEJO_TOKEN:?FORGEJO_TOKEN not set — open a new shell after nixos-rebuild switch}"

echo "==> Creating bare repo on sweetpea: ${NAME}.git"
ssh -t sweetpea "sudo -u git git init --bare ${REPOS_DIR}/${NAME}.git"

echo "==> Installing sync hook"
ssh sweetpea "sudo ln -sf /srv/git/hooks/forgejo-sync ${REPOS_DIR}/${NAME}.git/hooks/post-receive"

echo "==> Creating Forgejo repo"
PRIVATE_FLAG=""
[[ "$VISIBILITY" == "--private" ]] && PRIVATE_FLAG="--private"

tea \
    --url "$FORGEJO_URL" \
    --token "$FORGEJO_TOKEN" \
    repos create \
    --name "$NAME" \
    $PRIVATE_FLAG

echo ""
echo "Done. Add as remote with:"
echo "  git remote add home git@sweetpea-git:${REPOS_DIR}/${NAME}.git"
echo "  git push home main"
echo ""
echo "Forgejo: ${FORGEJO_URL}/${FORGEJO_USER}/${NAME}"
