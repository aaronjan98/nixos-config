{ config, lib, pkgs, ... }:

let
  cfg = config.aj.gitServer;

  gitHome = cfg.home;
  reposDir = cfg.reposDir;
in
{
  options.aj.gitServer = {
    enable = lib.mkEnableOption "Bare Git server over SSH using git-shell";

    home = lib.mkOption {
      type = lib.types.str;
      default = "/srv/git";
      description = "Home directory for the git system user.";
    };

    reposDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/git/repos";
      description = "Directory containing bare repositories (*.git).";
    };

    # Put one or more public keys here (recommended), or leave empty and manage manually.
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys allowed to access the git user.";
    };

    # If true, puts your normal user in the git group so you can manage repos locally too.
    addAjToGitGroup = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Add user 'aj' to the git group (optional).";
    };

    # Extra ssh hardening for user git
    lockDownSshForGitUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable forwarding, X11, TTY for git user in sshd config.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.git ];

    # Create git group + system user
    users.groups.git = {};

    users.users.git = {
      isSystemUser = true;
      group = "git";
      home = gitHome;
      createHome = true;
      shell = "${pkgs.git}/bin/git-shell";
      description = "Git server user (git-shell)";
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    # Optional: let aj manage /srv/git/repos directly
    users.users.aj = lib.mkIf cfg.addAjToGitGroup {
      extraGroups = [ "git" ];
    };

    # Create directories and permissions
    #
    # reposDir: 2775 sets the setgid bit so new files inherit group=git.
    systemd.tmpfiles.rules = [
      "d ${gitHome} 0755 git git - -"
      "d ${gitHome}/.ssh 0700 git git - -"
      "f ${gitHome}/.ssh/authorized_keys 0600 git git - -"
      "d ${reposDir} 2775 git git - -"
    ];

    # Ensure sshd is enabled (you already do this in host config; harmless duplication)
    services.openssh.enable = true;

    services.openssh.extraConfig = lib.mkIf cfg.lockDownSshForGitUser ''
      Match User git
        AllowTcpForwarding no
        X11Forwarding no
        PermitTTY no
    '';
  };
}

