# 2026-05-18 — Video summary service fix + Forgejo hook refinements

## What was worked on

Debugged and fixed the video summary pipeline (yt-dlp + Ollama + sauron API).
Fixed two bugs in `install-forgejo-hooks.sh`.
Renamed `clipper-video-summary` → `clipper-video-summary-client` on sweetpea.
Added READMEs to both clipper repos.
Ran initial Forgejo sync for all ~28 sweetpea repos.

## Video summary pipeline fixes

### yt-dlp "No supported JavaScript runtime"
Recent YouTube changes require deno/node for the default player client.
Fix: pass `"--extractor-args", "youtube:player_client=tv_embedded"` to yt-dlp.
`tv_embedded` bypasses the JS requirement and doesn't need a PO Token.
Also changed non-zero exit from yt-dlp (e.g. 429 on secondary subtitles) to
`logger.warning` instead of `raise RuntimeError` — allows partial success to continue.

### curl timeout too short
`process_clippings.sh` and `process_clippings_one.sh` used `--max-time 1800` (30 min).
CPU-based Ollama inference on a long video takes much longer.
Fix: increased to `--max-time 7200` (2 hours).

### sauron app.py out of sync
Patches were applied directly on sauron. Fixed by copying the live file back into
the `/tmp` clone of the git repo, committing, and pushing to sweetpea → Forgejo.

## install-forgejo-hooks fixes

1. **ssh stdin bug**: Inner `ssh sweetpea "readlink ..."` inside a
   `while ... done < <(ssh sweetpea "ls ...")` loop consumed stdin from the outer
   process substitution. Only the first repo was processed. Fix: `ssh -n`.

2. **Repo list ran locally**: `ls -d /srv/git/repos/*.git` was running on the laptop
   where that path doesn't exist. Fix: `ssh sweetpea "ls -d ${REPOS_DIR}/*.git"`.

3. **Multiple sudo TTY failures**: Each `ssh sweetpea "sudo ..."` needs its own TTY.
   Fix: collect all repos needing hooks, build one compound command, run with `ssh -t`.

## Repo rename

`clipper-video-summary.git` → `clipper-video-summary-client.git` on sweetpea.
Done manually by the user: `sudo mv` + new `ln -sf` for post-receive hook.
Forgejo repo renamed in UI. Local remote `local` in `~/Repositories/automation/video-summary`
may still point to the old name — update if that remote is ever used.

## Initial Forgejo sync

After hooks were installed on all repos, triggered mirror push with:
```bash
TOKEN=$(cat /run/secrets/forgejo_token)
ssh sweetpea "for repo in /srv/git/repos/*.git; do
  name=\$(basename \$repo .git)
  (cd \$repo && git -c safe.directory='*' push --mirror \
    \"https://aj:\${TOKEN}@git.aaronjanovitch.com/aj/\${name}.git\" 2>&1 | tail -3) \
    || echo \"  [failed]\"
done"
```
Result: dotfiles, password-store, raymer-homelab-docs had new commits; rest "Everything up-to-date".

## Files changed

- `scripts/install-forgejo-hooks.sh` — ssh -n fix, remote ls fix, batched sudo
- `sauron:/opt/ai-services/summarizer-api/app.py` — tv_embedded player_client, warning on yt-dlp non-zero
- `~/Repositories/automation/video-summary/process_clippings.sh` — --max-time 7200
- `~/Repositories/automation/video-summary/process_clippings_one.sh` — --max-time 7200
- `~/Repositories/automation/video-summary/README.md` — new client-side docs
- `sauron-clipper-summary` repo — README.md + synced app.py patches
- `Raymer/project-memory/forgejo-sync.md` — ssh -n bug, initial sync recipe, tea --login fix
