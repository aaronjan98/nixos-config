{ config, pkgs, lib, ... }:

let
  theme = import ../themes/limerence.nix;

  tmuxBattery =
    pkgs.writeShellScriptBin "tmux-battery"
      (builtins.readFile ../scripts/tmux-battery.sh);
in
{
  environment.systemPackages = with pkgs; [
    tmux
    wl-clipboard
    xclip
    tmuxBattery
  ];

  programs.tmux = {
    enable = true;

    # NixOS generates /etc/tmux.conf and sources these plugins automatically.
    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
      continuum
      vim-tmux-navigator
      yank
    ];

    extraConfig = ''
      ##### Prefix / basic behavior #####
      unbind C-b
      set -g prefix C-Space
      bind C-Space send-prefix

      set -g mouse on
      set -s escape-time 50
      set -g display-time 2000
      set -g history-limit 100000

      # vi keys in copy mode / status
      setw -g mode-keys vi
      set -g status-keys vi

      # Clipboard: tmux-yank uses this command for copy-to-clipboard
      set -g @override_copy_command '${pkgs.wl-clipboard}/bin/wl-copy'

      ##### Reload config #####
      bind r source-file /etc/tmux.conf \; display-message "Reloaded tmux (/etc/tmux.conf)"

      # Clear screen
      unbind k
      bind k send-keys C-l

      ##### Pane management #####
      setw -g aggressive-resize on
      bind-key R command-prompt -I "resize-pane -"
      bind -r BSpace resize-pane -L 5
      bind -r C-j resize-pane -D 5
      bind -r C-k resize-pane -U 5
      bind -r C-l resize-pane -R 5

      # Splits open in the current pane's path
      unbind %
      unbind '"'
      bind % split-window -h -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"

      # Marked pane switch
      bind Q switch-client -t'{marked}'

      ##### Pane navigation layer: Alt+Shift + hjkl (vim-aware) #####
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(n?vim)$'"
      
      bind -n M-H if-shell "$is_vim" "send-keys M-H" "select-pane -L"
      bind -n M-J if-shell "$is_vim" "send-keys M-J" "select-pane -D"
      bind -n M-K if-shell "$is_vim" "send-keys M-K" "select-pane -U"
      bind -n M-L if-shell "$is_vim" "send-keys M-L" "select-pane -R"

      ######################
      ### DESIGN CHANGES ###
      ######################

      DARKER_FG_COLOR=${theme.tmux.darkerFg}
      ACCENT_FG_COLOR=${theme.tmux.accentFg}
      LIGHTER_FG_COLOR=${theme.tmux.lighterFg}
      DEFAULT_BG_COLOR=${theme.tmux.defaultBg}
      BG_HIGHLIGHT_COLOR=${theme.tmux.bgHighlight}

      set-option -g message-command-style bg=$DEFAULT_BG_COLOR,fg=$DARKER_FG_COLOR
      set-option -g message-style         bg=$DEFAULT_BG_COLOR,fg=$DARKER_FG_COLOR
      set-option -g mode-style            bg=$BG_HIGHLIGHT_COLOR,fg=$DARKER_FG_COLOR

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

      # Right side status: date/time + battery from Nix script
      set-option -g status-right '#(date "+%H:%M %a %d.%m.%y") #(${tmuxBattery}/bin/tmux-battery)'

      set-option -g window-status-current-format '#{window_index}#(echo ":")#{window_name}#[fg='$ACCENT_FG_COLOR']#{window_flags}'
      set-option -g window-status-format         '#{window_index}#(echo ":")#{window_name}#[fg='$ACCENT_FG_COLOR']#{window_flags}'

      ##### Terminal color support #####
      set -g default-terminal "screen-256color"
      set -ga terminal-overrides ",screen-256color:Tc"

      ##### Resurrect / Continuum #####
      set -g @resurrect-dir '~/.config/tmux/resurrect'
      set -g @resurrect-strategy-nvim 'session'
      set -g @resurrect-capture-pane-contents 'on'
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '60'
    '';
  };
}

