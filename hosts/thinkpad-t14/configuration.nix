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

  # --- Lid close: lock, THEN suspend -----------------------------------------
  # Problem: with logind's default HandleLidSwitch=suspend, closing the lid
  # suspended the machine while hypridle was still launching hyprlock. During
  # that transition the panel powers off and the compositor stops servicing the
  # lock surface, so hyprlock stalled ~10s, lost the session lock ("yeeten") and
  # Hyprland showed its "lockscreen app died" screen. hyprlock only locks
  # reliably while the compositor is fully awake.
  #
  # Fix: tell logind to IGNORE the lid, and have Hyprland bind the lid switch to
  # `lock-and-suspend` (see ~/.config/hypr/conf.d/20-binds.conf). That locks
  # while everything is awake (fast + reliable) and only then suspends — so the
  # machine is already locked before it sleeps, with no race and no typing
  # window on wake.
  services.logind.settings.Login.HandleLidSwitch = "ignore";
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "lock-and-suspend" ''
      set -eu
      export PATH=/run/current-system/sw/bin:$PATH

      # Hide the desktop up front so nothing flashes while we lock/suspend.
      screen-blackout-on || true

      # Lock now, while the compositor is awake — this is the reliable path.
      loginctl lock-session

      # Don't suspend until hyprlock is actually up, so we never sleep mid-lock.
      # Bounded so a wedged hyprlock can't block suspend forever.
      for _ in $(seq 1 50); do
        pidof hyprlock >/dev/null 2>&1 && break
        sleep 0.1
      done
      # Brief settle so hyprlock finishes grabbing the session lock.
      sleep 0.4

      systemctl suspend
    '')
  ];
  # ---------------------------------------------------------------------------

  # Expose the mic-mute LED sysfs node to the video group so wpctl can toggle it.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", RUN+="${pkgs.bash}/bin/bash -c 'chgrp video /sys/class/leds/platform::micmute/brightness && chmod g+w /sys/class/leds/platform::micmute/brightness'"
  '';

  # Kanata layout — points to this host's kbd file. Framework gets its own copy.
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;

  # Syncthing peers — every other host this machine should sync with.
  aj.syncthing.devices = {
    framework-13.id = "HREY2AY-SFXA77Y-DII3WXI-PRXKRDT-CJTOLHQ-6DQHQ2R-BA2I3MZ-CKGQPQR";
    qwerty.id       = "F4NZQDP-JYNM45X-6M4J5QE-UY4RI3E-DYCRDWS-BX2L6KF-SIW3M3I-WG7I5AR";
  };

  # SSH public keys for the local git server on this machine.
  aj.gitServer.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+2LbKzQXnAojIRQPRsSBe6LwseuXyiyvByfzJA85E2 aj@thinkpad-t14"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
  ];

  # Set at initial install — never change after first nixos-install.
  system.stateVersion = "25.11";
}
