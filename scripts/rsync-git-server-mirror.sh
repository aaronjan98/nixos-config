#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="ssh.aaronjanovitch.com"
REMOTE_PORT="2222"
REMOTE_USER="aj"
REMOTE_PATH="/srv/git/repos/"
LOCAL_PATH="/srv/git/repos/"

# thinkpad-t14 is authorized for the git user only (git-shell).
# Rsync connects as aj, which uses id_rsa.
IDENTITY_FILE="/home/aj/.ssh/id_rsa"
if [[ ! -f "$IDENTITY_FILE" ]]; then
  IDENTITY_FILE="/home/aj/.ssh/thinkpad-t14"
fi

echo "==> Rsync mirror from ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH} -> ${LOCAL_PATH}"
echo "==> Using identity: ${IDENTITY_FILE}"

sudo mkdir -p "$LOCAL_PATH"
sudo chown -R git:git /srv/git || true
sudo chmod 2775 "$LOCAL_PATH" || true

# If you do NOT want strict mirroring, remove --delete
sudo rsync -aHAX --numeric-ids --delete --info=progress2 \
  -e "ssh -p ${REMOTE_PORT} -i ${IDENTITY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}" \
  "${LOCAL_PATH}"

sudo chown -R git:git "$LOCAL_PATH"
sudo chmod -R g+rwX "$LOCAL_PATH"

echo "==> Done."

