{ config, pkgs, ... }:

let
  tmuxBattery = pkgs.writeShellScriptBin "tmux-battery" ''
    set -eu

    # Prefer sysfs (fast, no deps). Typical ThinkPad: BAT0 (sometimes BAT1).
    for bat in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
      if [ -r "$bat/capacity" ]; then
        cap="$(cat "$bat/capacity")"
        stat=""

        if [ -r "$bat/status" ]; then
          s="$(cat "$bat/status" || true)"
          case "$s" in
            Charging) stat="+" ;;
            Discharging) stat="-" ;;
            Full) stat="=" ;;
            *) stat="" ;;
          esac
        fi

        printf "%s%%%s" "$cap" "$stat"
        exit 0
      fi
    done

    # Fallback to upower if sysfs not present
    if command -v upower >/dev/null 2>&1; then
      dev="$(upower -e | grep -m1 -E 'battery|BAT' || true)"
      if [ -n "$dev" ]; then
        pct="$(upower -i "$dev" | awk -F': *' '/percentage/ {print $2; exit}' | tr -d '\n' || true)"
        if [ -n "$pct" ]; then
          printf "%s" "$pct"
          exit 0
        fi
      fi
    fi

    printf "?"
  '';
in
{
  environment.systemPackages = with pkgs; [
    wl-clipboard
    xclip
    upower
  ];

  programs.tmux = {
    enable = true;

    # This makes /etc/tmux.conf the primary system config.
    # (tmux will still allow per-user overrides if you add ~/.tmux.conf)
    terminal = "screen-256color";

    plugins = with pkgs.tmuxPlugins; [
      tmux-sensible
      tmux-resurrect
      tmux-continuum
      vim-tmux-navigator
    ];

    extraConfig = ''
      ##### Prefix #####
      unbind C-b
      set -g prefix C-Space
      bind C-Space send-prefix

      ##### Mouse / responsiveness #####
      set -g mouse off
      set -s escape-time 50
      set -g display-time 2000

      ##### Pane resizing #####
      setw -g aggressive-resize on
      bind-key R command-prompt -I "resize-pane -"
      bind -r C-h resize-pane -L 5
      bind -r C-j resize-pane -D 5
      bind -r C-k resize-pane -U 5
      bind -r C-l resize-pane -R 5

      ##### Pane navigation (no prefix) #####
      bind -n M-b select-pane -L
      bind -n M-f select-pane -R

      ##### Reload config #####
      # On NixOS, this is the generated file:
      bind r source-file /etc/tmux.conf \; display-message "Reloaded tmux :)"

      ##### Split behavior #####
      unbind v
      unbind h
      bind % split-window -h -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"

      ##### Clear screen #####
      unbind k
      bind k send-keys C-l

      ##### Scrollback #####
      set -g history-limit 100000

      ##### Vi keys #####
      set -g status-keys vi
      setw -g mode-keys vi

      ##### Clipboard behavior #####
      set -s set-clipboard off
      bind P paste-buffer
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi x send-keys -X stop-selection
      unbind -T copy-mode-vi Enter

      # Wayland-friendly clipboard copy (wl-copy) with X11 fallback (xclip).
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "sh -c 'command -v wl-copy >/dev/null && wl-copy || xclip -in -selection clipboard'"
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "sh -c 'command -v wl-copy >/dev/null && wl-copy || xclip -in -selection clipboard'"

      ##### Marked pane shortcut #####
      bind Q switch-client -t'{marked}'

      ######################
      ### DESIGN CHANGES ###
      ######################

      DARKER_FG_COLOR=colour21
      ACCENT_FG_COLOR=colour124
      LIGHTER_FG_COLOR=purple
      DEFAULT_BG_COLOR=default
      BG_HIGHLIGHT_COLOR=#13040f

      set-option -g message-command-style bg=$DEFAULT_BG_COLOR,fg=$DARKER_FG_COLOR
      set-option -g message-style bg=$DEFAULT_BG_COLOR,fg=$DARKER_FG_COLOR
      set-option -g mode-style bg=$BG_HIGHLIGHT_COLOR,fg=$DARKER_FG_COLOR

      set-option -g status-position bottom
      set-window-option -g automatic-rename on
      set-option -g status-left-length 20

      set -g visual-activity off
      setw -g monitor-activity off
      set -g visual-bell off
      set -g visual-silence off
      set -g bell-action none

      set -g status on
      set-option -g status-style bg=$DEFAULT_BG_COLOR,fg=$DARKER_FG_COLOR
      set -g pane-active-border-style fg=$LIGHTER_FG_COLOR
      set -g pane-border-style fg=$DARKER_FG_COLOR
      set -g renumber-windows on

      # Right side status: date/time + Nix-provided battery script
      set-option -g status-right '#(date "+%H:%M %a %d.%m.%y") #(${tmuxBattery}/bin/tmux-battery)'

      set-option -g window-status-current-format '#{window_index}#(echo ":")#{window_name}#[fg='$ACCENT_FG_COLOR']#{window_flags}'
      set-option -g window-status-format '#{window_index}#(echo ":")#{window_name}#[fg='$ACCENT_FG_COLOR']#{window_flags}'

      ##### Terminal color support #####
      set -g default-terminal "screen-256color"
      set -ga terminal-overrides ",screen-256color:Tc"

      ######################
      ###### PLUGINS #######
      ######################

      # Resurrect
      set -g @resurrect-dir "#{HOME}/.config/tmux/resurrect"
      set -g @resurrect-strategy-nvim "session"
      set -g @resurrect-capture-pane-contents "on"

      # Continuum
      set -g @continuum-restore "on"
      set -g @continuum-save-interval "60"
    '';
  };
}
