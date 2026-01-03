{ config, pkgs, lib, ... }:

{
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    # enableSSHSupport = true;  # use GPG for SSH keys
  };

  # Override the gpg-agent.conf to ensure pinentry is set correctly
  environment.etc."gnupg/gpg-agent.conf".text = lib.mkForce ''
    pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
  '';

  # Set the GPG_TTY environment variable globally
  environment.variables = {
    GPG_TTY = "$(tty)";
  };
}
