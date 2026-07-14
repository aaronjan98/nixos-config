{ config, lib, pkgs, ... }:

# Framework 13 AMD host-specific overrides. Everything shared lives in
# ../common/default.nix — this file only contains what differs per machine.
#
# nixos-hardware module (framework-13-7040-amd) is applied in flake.nix,
# not here, because it comes from an external flake input.

let
  frameworkWorkspaceRules = lib.concatStringsSep "\n" (
    map
      (workspace:
        "    workspace = ${toString workspace}, monitor:eDP-1, gapsin:13, gapsout:35")
      (lib.range 1 99)
  );
  frameworkSizeRules = lib.concatStringsSep "\n" (
    [
      "    # Framework-only btop terminal size for Super+P."
      "    windowrulev2 = size 1730 1040, class:^(btop-scratch)$"
      ""
      "    # Framework-only app sizes for Super+P."
    ]
    ++ map
      (workspace:
        "    windowrulev2 = size 1986 1270, onworkspace:${toString workspace}, class:^(firefox|kitty|com\\.mitchellh\\.ghostty|vesktop|org-jdownloader-update-launcher-JDLauncher|codium|com\\.wolfram\\.Wolfram\\.14\\.3)$")
      (lib.range 1 99)
  );
in {
  imports = [
    ./hardware-configuration.nix
    ../common/default.nix
    ../../modules/home-assistant.nix
    ../../modules/orchestrator.nix
  ];

  networking.hostName = "framework-13";

  # Framework 13 AMD does not need pcie_aspm=off (ThinkPad-specific).
  # Add Framework-specific kernel params here if needed after install.

  # Quickshell UI scale — compensates for higher DPI at Hyprland scale=1.
  # ThinkPad uses the QML fallback (1.25); adjust this value to taste.
  environment.sessionVariables = {
    QS_UI_SCALE = "1.75";
    XCURSOR_THEME = "Breeze_Hacked";
    XCURSOR_SIZE = "72";
  };

  # Hyprland per-host overrides — loaded last (99-) so they win over dotfiles defaults.
  # Keep this in sync with the session cursor variables above.
  environment.etc."hypr/conf.d/99-host.conf".text = ''
    env = XCURSOR_THEME,Breeze_Hacked
    env = XCURSOR_SIZE,72
    exec-once = hyprctl setcursor Breeze_Hacked 72

${frameworkSizeRules}

${frameworkWorkspaceRules}

    # Samsung external monitor workspace row. Keep laptop spacing compact while
    # giving tiled windows on the ultrawide more breathing room.
    workspace = 101, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 102, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 103, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 104, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 105, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 106, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 107, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 108, monitor:DP-1, gapsin:12, gapsout:36
    workspace = 109, monitor:DP-1, gapsin:12, gapsout:36
  '';

  # Kanata layout — identical to ThinkPad for now; diverge here as needed.
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;

  # Syncthing peers — every other host this machine should sync with.
  aj.syncthing.devices = {
    thinkpad-t14.id = "JGO6ECN-PM4ILSY-YMPRV7C-A4MR5L5-JQAOCFQ-UKXMT4N-UE6CYJE-PLDVXAB";
    qwerty.id       = "F4NZQDP-JYNM45X-6M4J5QE-UY4RI3E-DYCRDWS-BX2L6KF-SIW3M3I-WG7I5AR";
  };

  # SSH public keys for the local git server on this machine.
  # Add the Framework's own ed25519 key here after first boot.
  aj.gitServer.authorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpHu1YwxlgUENahANYgmkk2cNEGOEcurdNJQMIVR8PF aj@framework-13"
  ];

  # SSH public keys for logging in as aj on this machine.
  users.users.aj.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+2LbKzQXnAojIRQPRsSBe6LwseuXyiyvByfzJA85E2 aj@thinkpad-t14"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
  ];

  # SSH — open for remote access now that this machine stays home as a server.
  services.openssh = {
    enable = true;
    listenAddresses = lib.mkForce [
      { addr = "127.0.0.1"; port = 22; }
      { addr = "::1"; port = 22; }
      { addr = "0.0.0.0"; port = 22; }
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  # Lid close should not suspend — machine runs headless with lid shut.
  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchExternalPower = "ignore";

  # Set at initial install — update this to match the actual NixOS installer version used.
  system.stateVersion = "25.11";
}
