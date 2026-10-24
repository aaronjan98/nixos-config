{ config, lib, pkgs, ... }:

# Event-driven self-healing for Matter nodes that go `unavailable` in Home
# Assistant while general connectivity is fine (the Kasa speaker plug, node 6).
#
# Root cause: the plug is reached over Matter -> mDNS *multicast* discovery. Over
# time the Deco mesh stops delivering the plug's operational mDNS record to
# framework-13 — it still answers unicast ping, but matter-server's discovery
# times out ("Timeout waiting for mDNS resolution"), marks the node offline, and
# the HA entity sits `unavailable`, so `speaker_power` / `ensure_speakers_on`
# can't reach the speakers.
# Proven fix (no reboot): RE-ASSOCIATE WIFI (restores the multicast path), THEN
# restart matter-server (after it gives up a node it goes dormant and won't retry
# on its own). Order matters: wifi first, matter-server second.
# See voice-assistant memory/2026-10-24 speaker-unavailable-wifi-reassociate-fix.md
# and memory/2026-08-29 speaker-plug-matter-recovery.md.
#
# net-watchdog's Matter-layer sibling: that one (wifi-reliability.nix) is a 30s
# timer for total link hangs; this one is purely EVENT-driven — it follows
# matter-server's journal and acts the moment it logs that it gave up on a node.
# A cooldown prevents thrashing (the heal itself briefly perturbs the link).

let
  wifiIface = "wlp192s0";
  cooldownSec = 300;   # ignore further triggers for 5 min after acting

  matterPlugHealer = pkgs.writeShellScript "matter-plug-healer" ''
    export PATH=${lib.makeBinPath [
      pkgs.coreutils pkgs.systemd pkgs.networkmanager pkgs.util-linux
    ]}
    set -u

    iface="${wifiIface}"
    cooldown=${toString cooldownSec}
    last=0

    # The authoritative "I gave up on a node" line matter-server logs after it
    # exhausts its resubscription backoff. Only node 6 (the speaker plug) and the
    # controller live on this fabric, so matching the generic line is fine and
    # also covers any future node.
    marker="Node considered offline, shutdown subscription"

    logger -t matter-plug-healer "watching matter-server journal for offline nodes"

    # -f follow, -n0 only new lines, --output=cat raw message. journalctl -u
    # follows the unit across restarts, so our own matter-server restart below
    # doesn't break the watch (and its fresh startup logs don't match the marker).
    journalctl -u matter-server.service -f -n0 --output=cat 2>/dev/null \
      | while IFS= read -r line; do
          case "$line" in
            *"$marker"*) : ;;
            *) continue ;;
          esac

          now="$(date +%s)"
          if [ "$((now - last))" -lt "$cooldown" ]; then
            logger -t matter-plug-healer "node offline again within cooldown; skipping"
            continue
          fi
          last="$now"

          logger -t matter-plug-healer "matter-server declared a node offline — re-associating $iface"
          nmcli device disconnect "$iface" >/dev/null 2>&1 || true
          sleep 2
          nmcli device connect "$iface" >/dev/null 2>&1 || true
          # Let the link come up + the NM dispatcher re-assert IPv6 + mDNS settle
          # before poking matter-server to re-discover over the healed path.
          sleep 12
          logger -t matter-plug-healer "restarting matter-server to force fresh node discovery"
          systemctl restart matter-server.service || true
          logger -t matter-plug-healer "heal cycle done; matter-server will re-subscribe"
        done
  '';
in {
  systemd.services.matter-plug-healer = {
    description = "Re-associate wifi + restart matter-server when a Matter node goes offline (mDNS multicast drop)";
    after = [ "matter-server.service" "network-online.target" ];
    wants = [ "matter-server.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${matterPlugHealer}";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
