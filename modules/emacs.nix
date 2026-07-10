{ pkgs, ... }:

# Emacs — system-layer tool for org-agenda, org-capture, and emacs-everywhere.
# User config lives in ~/.doom.d/ (tracked in dotfiles).
# Doom Emacs runtime lives in ~/.emacs.d/ (managed by Doom, not Nix).
#
# After first rebuild, start the daemon manually once:
#   systemctl --user enable --now emacs
# Subsequent logins start it automatically.

{
  environment.systemPackages = [ pkgs.emacs-pgtk ];

  services.emacs = {
    enable        = true;
    package       = pkgs.emacs-pgtk;
    defaultEditor = true;   # sets EDITOR=emacsclient system-wide
  };
}
