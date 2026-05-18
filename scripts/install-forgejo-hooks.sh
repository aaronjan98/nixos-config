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
    "${FORGEJO_URL}/api/v1/repos/search?limit=50&token=${FORGEJO_TOKEN}" \
    | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//')

for repo_path in "$REPOS_DIR"/*.git; do
    name="$(basename "$repo_path" .git)"
    hook="$repo_path/hooks/post-receive"

    if ! echo "$FORGEJO_REPOS" | grep -qx "$name"; then
        echo "    SKIP $name (no matching Forgejo repo)"
        continue
    fi

    if [[ -L "$hook" && "$(readlink "$hook")" == "$HOOK_TARGET" ]]; then
        echo "    OK   $name (hook already installed)"
        continue
    fi

    echo "    INSTALL $name"
    ssh sweetpea "sudo ln -sf ${HOOK_TARGET} ${repo_path}/hooks/post-receive"
done

echo "==> Done."
