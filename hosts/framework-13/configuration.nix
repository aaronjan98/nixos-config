{ config, lib, pkgs, ... }:

# Framework 13 AMD host-specific overrides. Everything shared lives in
# ../common/default.nix — this file only contains what differs per machine.
#
# nixos-hardware module (framework-13-7040-amd) is applied in flake.nix,
# not here, because it comes from an external flake input.

{
  imports = [
    ./hardware-configuration.nix
    ../common/default.nix
    ../../modules/pentest.nix
  ];

  networking.hostName = "framework-13";

  # Framework 13 AMD does not need pcie_aspm=off (ThinkPad-specific).
  # Add Framework-specific kernel params here if needed after install.

  # Quickshell UI scale — compensates for higher DPI at Hyprland scale=1.
  # ThinkPad uses the QML fallback (1.25); adjust this value to taste.
  environment.sessionVariables.QS_UI_SCALE = "1.6";

  # Hyprland per-host overrides — loaded last (99-) so they win over dotfiles defaults.
  # Cursor size bumped from 35→44 to compensate for higher DPI at scale=1.
  environment.etc."hypr/conf.d/99-host.conf".text = ''
    env = XCURSOR_SIZE,55
    exec-once = hyprctl setcursor Breeze_Hacked 55
  '';

  # Kanata layout — identical to ThinkPad for now; diverge here as needed.
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;

  # SSH public keys for the local git server on this machine.
  # Add the Framework's own ed25519 key here after first boot.
  aj.gitServer.authorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpHu1YwxlgUENahANYgmkk2cNEGOEcurdNJQMIVR8PF aj@framework-13"
  ];

  # Set at initial install — update this to match the actual NixOS installer version used.
  system.stateVersion = "25.11";
}
