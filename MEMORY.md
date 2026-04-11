# MEMORY.md

## Agent Procedures

### Rebuilding and Testing
When applying NixOS configuration changes, agents MUST use the following aliases to ensure consistency:

- **`nrt`**: Used for testing or dry-run of the configuration (e.g., `sudo nixos-rebuild test`).
- **`nrs`**: Used for applying the final configuration (e.g., `sudo nixos-rebuild switch`).

Always run `nrt` first to verify the configuration builds correctly before applying it with `nrs`.

---

## Excluding KDE Plasma Packages

To remove a package that ships with `services.desktopManager.plasma6`, use:

```nix
environment.plasma6.excludePackages = [ pkgs.kdePackages.<name> ];
```

Currently excluded: `dolphin`, `dolphin-plugins` (replaced by Nautilus for GUI file management).

---

## Common Tasks

### Adding a Split DNS Entry
When adding a new local domain (e.g., `photos.local`):

1. **Configuration:** Update `modules/caddy.nix`:
   - Add the domain to `networking.hosts."127.0.0.1"`.
   - Add a new `virtualHosts` entry with the appropriate `reverse_proxy` target (e.g., `http://qwerty:<port>`).
2. **Apply Changes:** 
   - Run `nrt` first to verify the configuration is valid.
   - Run `nrs` to apply and switch.
   - *Note:* Simply restarting the `caddy` service is insufficient because `/etc/hosts` needs to be updated by NixOS to resolve the new `.local` domain.
3. **Verification:** Check the domain in a browser or use `curl -I http://domain.local`.
