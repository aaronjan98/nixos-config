{ config, lib, pkgs, ... }:

# ThinkPad T14 host-specific overrides. Everything shared lives in
# ../common/default.nix — this file only contains what differs per machine.

{
  imports = [
    ./hardware-configuration.nix
    ../common/default.nix
  ];

  networking.hostName = "nixos";

  # pcie_aspm=off works around a suspend/resume instability on this hardware.
  boot.kernelParams = [ "pcie_aspm=off" ];

  # Expose the mic-mute LED sysfs node to the video group so wpctl can toggle it.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", RUN+="${pkgs.bash}/bin/bash -c 'chgrp video /sys/class/leds/platform::micmute/brightness && chmod g+w /sys/class/leds/platform::micmute/brightness'"
  '';

  # Kanata layout — points to this host's kbd file. Framework gets its own copy.
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;

  # Syncthing peers — every other host this machine should sync with.
  aj.syncthing.devices = {
    framework-13.id = "HREY2AY-SFXA77Y-DII3WXI-PRXKRDT-CJTOLHQ-6DQHQ2R-BA2I3MZ-CKGQPQR";
  };

  # SSH public keys for the local git server on this machine.
  aj.gitServer.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+2LbKzQXnAojIRQPRsSBe6LwseuXyiyvByfzJA85E2 aj@thinkpad-t14"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
  ];

  # Set at initial install — never change after first nixos-install.
  system.stateVersion = "25.11";
}
