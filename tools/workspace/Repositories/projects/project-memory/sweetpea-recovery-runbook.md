# sweetpea recovery cheat-sheet (quick reference)

Terse command card for when sweetpea won't come back. Narrative + prevention:
zettelkasten `Inside/Projects/Homelab/sweetpea — boot & network recovery runbook.md`.
(This file is nix-mirrored / untracked — do not commit.)

## Facts
- sweetpea = LAN DNS+DHCP (dnsmasq @ **10.0.50.47**, iface **enp0s31f6**). Gateway = **10.0.50.1** (NOT sweetpea). VLAN30 bridge br-vlan30 = 192.168.30.1/24.
- Down sweetpea => house loses DNS (+DHCP) => "no internet" even though gateway is fine.
- Boot: separate `/boot` = /dev/sda2; root = LVM `/dev/mapper/ubuntu--vg-ubuntu--lv`. Kernels: 5.15.0-179 (good), -181 (current).
- VMs: libvirt; `arrs-vm` disk on mergerfs pool `/mnt/vm-nas` = /media/external0 (sdb) : /media/external1 (sdc, EMPTY). Pool needs BOTH branches to mount.
- Access when down: physical console (monitor+keyboard). Use IPs, not hostnames. Can't reach 10.0.50.x from another WiFi.

## 1. GRUB "file '/boot/vmlinuz-…' not found" (menu won't auto-boot = recordfail)
At `grub>` (press c):
  ls /
  linux /vmlinuz-5.15.0-179-generic root=/dev/mapper/ubuntu--vg-ubuntu--lv ro
  initrd /initrd.img-5.15.0-179-generic
  boot
Note: `/vmlinuz`, NOT `/boot/vmlinuz`. Then once up: `sudo update-grub`; verify `grep -m2 '^\s*linux' /boot/grub/grub.cfg` shows `/vmlinuz-…`.

## 2. Wrong IP (10.0.50.19) / no internet (dead default via 192.168.1.1)
  ip -brief addr show enp0s31f6 ; ip route | grep default
Make 01-network-manager-all.yaml static (10.0.50.47/24, via 10.0.50.1, dhcp4:false, keep br-vlan30), then:
  echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
  sudo mv /etc/netplan/50-cloud-init.yaml ~/50-cloud-init.yaml.removed
  sudo netplan apply          # `netplan try` refuses (br-vlan30 bridge) — keep console access

## 3. dnsmasq failed (cannot assign 100.97.56.82 = Tailscale IP, late on boot)
Needs 10.0.50.47 present (step 2 first). Drop-in already installed:
  /etc/systemd/system/dnsmasq.service.d/retry.conf  => Restart=on-failure, StartLimitIntervalSec=0, After=tailscaled.service
  sudo systemctl daemon-reload && sudo systemctl restart dnsmasq ; systemctl is-active dnsmasq

## 4. docker exec escapes to host FS (exec shows Ubuntu, /app missing)
Reboot clears it. Verify: docker run -d --name t2 alpine sleep 20 && docker exec t2 cat /etc/alpine-release  (=> alpine ver)

## 5. Service container down after reboot (e.g. nginx Exited 137)
  docker start nginx    (or: docker compose -f /opt/reverse-proxy/docker-compose.yml up -d)  # restores movies.home etc.

## 6. VM storage gone (/mnt/vm-nas not mounted b/c a drive is unplugged)
Reconnect drive (hot-plug ok), match UUID in lsblk, then:
  sudo mount /media/external1
  sudo mount /mnt/vm-nas
  sudo virsh list --all ; sudo virsh start arrs-vm
(SSH to VM goes No-route -> Refused -> ok as it boots.)

## Prevention
- Reboot after kernel updates promptly; keep /boot pruned (`apt autoremove --purge`); don't accumulate long uptime across kernel installs.
- netplan must be authoritative (no live-only `ip addr`); cloud-init network already disabled — keep it.
- dnsmasq hardened (retry drop-in). Consider secondary DNS/DHCP to kill the single-point-of-failure.
- Don't yank drives from the mergerfs pool; external1 is empty (could drop it to single-drive to free the USB port).
- Keep a rescue USB around.
