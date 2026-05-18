#!/usr/bin/env bash
# One-time script: installs the forgejo-sync post-receive hook on all bare repos
# that already have a matching Forgejo repo. Safe to re-run.
set -euo pipefail

REPOS_DIR="/srv/git/repos"
HOOK_TARGET="/srv/git/hooks/forgejo-sync"
FORGEJO_URL="https://git.aaronjanovitch.com"
FORGEJO_USER="aj"

: "${FORGEJO_TOKEN:?FORGEJO_TOKEN not set}"

echo "==> Fetching existing Forgejo repos for ${FORGEJO_USER}..."
FORGEJO_REPOS=$(curl -s \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    "${FORGEJO_URL}/api/v1/repos/search?limit=50" \
    | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//')

# Build list of repos that need hooks installed
TO_INSTALL=()
while IFS= read -r repo_dir; do
    name="$(basename "$repo_dir" .git)"

    if ! echo "$FORGEJO_REPOS" | grep -qx "$name"; then
        echo "    SKIP $name (no matching Forgejo repo)"
        continue
    fi

    current_link=$(ssh -n sweetpea "readlink ${repo_dir}/hooks/post-receive 2>/dev/null || true")
    if [[ "$current_link" == "$HOOK_TARGET" ]]; then
        echo "    OK   $name (hook already installed)"
        continue
    fi

    echo "    QUEUE $name"
    TO_INSTALL+=("$repo_dir")
done < <(ssh sweetpea "ls -d ${REPOS_DIR}/*.git")

if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
    echo "==> Nothing to install."
    exit 0
fi

echo "==> Installing hooks (one sudo prompt)..."
CMDS=""
for repo_dir in "${TO_INSTALL[@]}"; do
    CMDS+="sudo ln -sf ${HOOK_TARGET} ${repo_dir}/hooks/post-receive && "
done
CMDS="${CMDS% && }"

ssh -t sweetpea "$CMDS"

echo "==> Done."
