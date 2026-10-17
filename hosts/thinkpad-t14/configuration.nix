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

  # --- Lid close: lock, THEN suspend (unless coffee mode is on) --------------
  # Problem: with logind's default HandleLidSwitch=suspend, closing the lid
  # suspended the machine while hypridle was still launching hyprlock. During
  # that transition the panel powers off and the compositor stops servicing the
  # lock surface, so hyprlock stalled ~10s, lost the session lock ("yeeten") and
  # Hyprland showed its "lockscreen app died" screen. hyprlock only locks
  # reliably while the compositor is fully awake.
  #
  # Fix: tell logind to IGNORE the lid, and have Hyprland bind the lid switch to
  # `lid-close-handler` / `lid-open-handler` (see ~/.config/hypr/conf.d/20-binds.conf).
  # The close handler locks while everything is awake (fast + reliable) and
  # only then suspends — so the machine is already locked before it sleeps,
  # with no race and no typing window on wake.
  #
  # Coffee-mode exception: the quickshell bar's coffee-cup button stops the
  # `hypridle` user service to keep the screen/system awake indefinitely (see
  # HypridleCtl.qml). Before this, closing the lid still suspended regardless
  # — coffee mode never touched the lid-switch bind. Now the close handler
  # checks hypridle's state: if it's stopped (coffee mode), the lid closing
  # only blackens the screen (no lock, no suspend) so whatever's running
  # keeps running; the open handler un-blackens it. If hypridle is active
  # (normal mode), behavior is unchanged from before.
  services.logind.settings.Login.HandleLidSwitch = "ignore";
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  environment.systemPackages = [
    # TEMP DIAGNOSTIC (2026-09-29): `logger -t wake-diag` markers bracket each
    # phase so we can measure, on the next slow/missed-keypress wake, exactly
    # where the time goes (blackout, lock, hyprlock startup, suspend itself).
    # `logger` writes straight to the journal regardless of who's holding this
    # script's stdout, so `journalctl -t wake-diag` finds these markers even
    # though the script runs under Hyprland's exec, not a systemd unit. See
    # memory/2026-09-29 for the investigation this supports; revert once
    # resolved.
    (pkgs.writeShellScriptBin "lid-close-handler" ''
      set -eu
      export PATH=/run/current-system/sw/bin:$PATH

      diag() { logger -t wake-diag "lid-close-handler: $1 @ $(date +%s.%3N)"; }

      diag "start (lid closed)"

      if ! systemctl --user is-active --quiet hypridle; then
        # Coffee mode: hypridle is stopped, so don't lock or suspend — just
        # blank the display. DPMS off (not screen-blackout-on's brightness-0)
        # because brightness-0 is only a backlight PWM scale-down — the
        # compositor keeps rendering real content to the panel, and ambient
        # room light reflecting off brighter pixels stays faintly visible.
        # DPMS off blanks the output at the DRM level (no signal at all),
        # same mechanism the 15-min idle listener below already uses for a
        # true full blackout.
        diag "coffee mode (hypridle stopped) - dpms off only, no lock/suspend"
        hyprctl dispatch dpms off || true
        exit 0
      fi

      # Hide the desktop up front so nothing flashes while we lock/suspend.
      screen-blackout-on || true
      diag "blackout-on done"

      # Lock now, while the compositor is awake — this is the reliable path.
      loginctl lock-session
      diag "loginctl lock-session issued"

      # Don't suspend until hyprlock is actually up, so we never sleep mid-lock.
      # Bounded so a wedged hyprlock can't block suspend forever.
      for _ in $(seq 1 50); do
        pidof hyprlock >/dev/null 2>&1 && break
        sleep 0.1
      done
      diag "hyprlock pid seen (or wait exhausted)"
      # Settle so hyprlock finishes grabbing the session lock AND its `screenshot`
      # background finishes the wlr-screencopy before we suspend — a suspend
      # landing mid-copy is what brought back the "lockscreen app died" screen.
      sleep 1.5

      diag "calling systemctl suspend"
      systemctl suspend
      diag "systemctl suspend returned (system resumed)"
    '')
    (pkgs.writeShellScriptBin "lid-open-handler" ''
      set -eu
      export PATH=/run/current-system/sw/bin:$PATH

      # Only act here in coffee mode: a normal-mode lid close suspended the
      # machine, and hypridle's own after_sleep_cmd (modules/hypr-idle-lock.nix)
      # already restores dpms/brightness on resume. Firing dpms on again here
      # in that case is harmless (dpms on is idempotent) but unnecessary.
      if ! systemctl --user is-active --quiet hypridle; then
        hyprctl dispatch dpms on || true
      fi
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

  # Same two keys framework-13 authorizes for direct `aj` login — without
  # this, PasswordAuthentication=false below would leave no auth method that
  # actually succeeds once sshd is reachable.
  users.users.aj.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+2LbKzQXnAojIRQPRsSBe6LwseuXyiyvByfzJA85E2 aj@thinkpad-t14"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
  ];

  # SSH public keys for the local git server on this machine.
  aj.gitServer.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+2LbKzQXnAojIRQPRsSBe6LwseuXyiyvByfzJA85E2 aj@thinkpad-t14"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
  ];

  # SSH over Tailscale — lets the Framework (and other tailnet peers) reach this
  # laptop by its 100.x address, e.g. `rsync` the Obsidian plugins between the two
  # (see modules/syncthing.nix). Common only listens on loopback; widen the bind
  # to all interfaces but open port 22 ONLY on tailscale0, so sshd is never
  # exposed on untrusted travel wifi. Key-only, no root login. Mirrors the
  # Framework's block (hosts/framework-13/configuration.nix).
  services.openssh = {
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

  # Set at initial install — never change after first nixos-install.
  system.stateVersion = "25.11";
}
