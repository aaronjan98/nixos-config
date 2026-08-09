# 2026-08-09 — Adding WiFi networks to NetworkManager secrets

Time: 08:41 -03 (Maceió)

## What was worked on
Added two saved WiFi networks (`VIRUS PERIGOSO_5G`, `CONEKTAR-NDA-5G`) to the
declarative SOPS-managed NetworkManager profiles, and documented the whole
workflow (which was previously undocumented). Committed as
`bf3f4e8 add Maceió secrets to network manager`.

## How the WiFi-profile system works (recap)
- `modules/networkmanager-profiles.nix` holds an `nmProfiles` list mapping each
  encrypted secret → the exact on-disk filename NetworkManager expects.
- Each `secrets/networkmanager/<secret>.nmconnection` is SOPS-encrypted (binary
  format), decrypted at boot to `/run/secrets/nm/<secret>`, then copied as a
  real file into `/etc/NetworkManager/system-connections/` *before*
  NetworkManager starts (activation script + `nm-sops-profiles.service`).
- `.sops.yaml` auto-encrypts anything under `secrets/` with the `aj_age` key.

## The workflow (now also in docs/SECRETS.md)
1. `nix shell nixpkgs#sops nixpkgs#age` (sops is NOT installed system-wide)
2. `export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt`
3. `sudo cat "/etc/NetworkManager/system-connections/<SSID>.nmconnection" > secrets/networkmanager/<name>.nmconnection`
4. `sops -e -i --input-type binary --output-type binary secrets/networkmanager/<name>.nmconnection`
5. verify `head -c 15 ...` shows `{"data":"ENC[`
6. add `{ secret = "<name>"; target = "<exact /etc filename>.nmconnection"; }` to `nmProfiles`
7. `sudo nixos-rebuild switch`

## Key insights / gotchas hit
- **A saved-but-not-connected network is added identically** — the plaintext
  profile already lives in `/etc/NetworkManager/system-connections/` once saved;
  being connected is irrelevant.
- **`error loading config: no matching creation rules found`** came from piping
  plaintext through `/dev/stdin` with a `>` redirect. SOPS matches its creation
  rule against the *input* path (`/dev/stdin`), not the shell redirect target,
  so `^secrets/` never matched. Fix: copy the file under `secrets/` first, then
  `sops -e -i` in place (path then matches). `--filename-override` is the
  alternative if you want to avoid plaintext ever touching disk.
- Retrieving a currently-connected WiFi password: `nmcli -s connection show "<SSID>" | grep psk` (needs `-s`; often root).

## Decisions
- Left the `virus-perigoso-5G` file lowercase but `CONEKTAR-NDA-5G` uppercase —
  casing of the `secret`/filename is purely cosmetic, works either way; existing
  convention is lowercase-kebab.
- New secret files ended up mode 0644 vs 0600 on the older ones — harmless since
  the contents are encrypted; not normalized.

## Next steps / open
- Optional cleanup: rename `CONEKTAR-NDA-5G` secret to lowercase kebab and
  `chmod 600 secrets/networkmanager/*.nmconnection` for consistency.
- Verify both networks actually associate after the rebuild (not re-checked this
  session).

Related: [[keyboard accents emoji and host-scaled dotfiles]]
