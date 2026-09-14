{ pkgs, ... }:

# tmux-continuum repoints the `last` symlink (the pointer continuum-restore
# follows at boot) as part of each save. If the machine shuts down mid-save, the
# `.txt` snapshot never finishes writing but `last` is already repointed at it —
# leaving a dangling pointer. continuum-restore then finds nothing and silently
# starts empty sessions, even though the previous good save is still on disk.
#
# This login-time oneshot repairs that: if `last` is missing or dangling, it
# repoints it to the newest save that actually contains pane data. It only acts
# when `last` is broken, so a healthy pointer is never touched. Runs at
# default.target (login), before the first terminal starts the tmux server and
# triggers continuum-restore.
let
  repair = pkgs.writeShellApplication {
    name = "tmux-resurrect-repair";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep ];
    text = ''
      dir="''${TMUX_RESURRECT_DIR:-$HOME/.config/tmux/resurrect}"
      last="$dir/last"

      # -e follows the symlink: true only when it resolves to an existing file.
      if [ -e "$last" ]; then
        exit 0   # pointer is healthy — leave it alone
      fi

      # last is absent or dangling. Pick the newest save that has pane data
      # (an interrupted save is header-only or missing), skipping bad ones.
      newest=""
      while IFS= read -r f; do
        if grep -q "^pane"$'\t' "$f" 2>/dev/null; then
          newest="$f"
          break
        fi
      done < <(ls -1t "$dir"/tmux_resurrect_*.txt 2>/dev/null || true)

      if [ -z "$newest" ]; then
        echo "tmux-resurrect-repair: no valid save to recover; leaving 'last' as-is" >&2
        exit 0
      fi

      ln -sfn "$(basename "$newest")" "$last"
      echo "tmux-resurrect-repair: repaired dangling 'last' -> $(basename "$newest")"
    '';
  };
in
{
  systemd.user.services.tmux-resurrect-repair = {
    description = "Repair a dangling tmux-resurrect 'last' pointer after an interrupted save";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${repair}/bin/tmux-resurrect-repair";
    };
  };
}
