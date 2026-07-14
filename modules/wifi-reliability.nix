{ config, lib, pkgs, ... }:

# WiFi reliability for framework-13's MediaTek MT7925 (mt7925e driver).
#
# Symptom: the card periodically soft-hangs — it stays "associated" with NO
# kernel error, but silently stops passing traffic (can't even ping 8.8.8.8),
# and only recovers when the link is re-associated (e.g. restarting
# NetworkManager). Since this host runs headless as the always-on voice/HA
# server, an unattended hang takes down Home Assistant + the orchestrator.
#
# Two layers:
#   1. Disable L1 ASPM on the card. L1 ASPM is the common trigger for these
#      hangs on MediaTek wifi on AMD platforms. Applied three ways so it sticks:
#      a udev rule (re-applies on every PCI (re)bind, incl. after a module
#      reload), a tmpfiles write (at boot / on switch), and the watchdog
#      re-asserts it after any reload. No reboot required.
#   2. A connectivity watchdog timer that auto-recovers any hang that still
#      slips through (restart NetworkManager, escalate to an mt7925e reload),
#      so the host self-heals while unattended.
#
# If hangs persist even with L1 ASPM off, escalate to
#   boot.kernelParams = [ "pcie_aspm=off" ];   # system-wide, needs a reboot.

let
  # MT7925 (wlp192s0). Address is stable for this board; the watchdog and
  # tmpfiles reference it directly.
  wifiPciPath = "/sys/bus/pci/devices/0000:c0:00.0";

  netWatchdog = pkgs.writeShellScript "net-watchdog" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.iputils pkgs.kmod pkgs.systemd pkgs.util-linux ]}
    set -u

    targets="10.0.50.1 1.1.1.1 8.8.8.8"   # gateway, then two public anycasts

    ok() {
      for t in $targets; do
        ping -c1 -W2 "$t" >/dev/null 2>&1 && return 0
      done
      return 1
    }

    # Two strikes, 5s apart, before acting — avoid bouncing on a transient blip.
    ok && exit 0
    sleep 5
    ok && exit 0

    logger -t net-watchdog "no connectivity (gw/1.1.1.1/8.8.8.8 failed twice) — restarting NetworkManager"
    systemctl restart NetworkManager
    sleep 8

    if ! ok; then
      logger -t net-watchdog "still down after NM restart — reloading mt7925e"
      modprobe -r mt7925e 2>/dev/null && sleep 2 && modprobe mt7925e 2>/dev/null
      sleep 8
    fi

    # Re-assert L1 ASPM off in case the device re-bound during recovery.
    echo 0 > ${wifiPciPath}/link/l1_aspm 2>/dev/null || true

    if ok; then
      logger -t net-watchdog "connectivity restored"
    else
      logger -t net-watchdog "STILL DOWN after recovery attempts"
    fi
  '';
in {
  # (1) Disable L1 ASPM on the MT7925.
  # udev: re-applies on every PCI (re)bind (survives a module reload).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:c0:00.0", ATTR{link/l1_aspm}="0"
  '';
  # tmpfiles: also set it at boot / on nixos-rebuild switch.
  systemd.tmpfiles.rules = [
    "w ${wifiPciPath}/link/l1_aspm - - - - 0"
  ];

  # (2) Connectivity watchdog — oneshot script fired by a 30s timer.
  systemd.services.net-watchdog = {
    description = "Recover MT7925 wifi from silent link hangs";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${netWatchdog}";
    };
  };

  systemd.timers.net-watchdog = {
    description = "Run the network watchdog every 30s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
    };
  };
}
