# Project: Codifying Raymer Homelab State

## Goal
Establish a reproducible, versioned record of the Raymer homelab — its machines, their config
files, and their documentation — visible and navigable from the NixOS machine.

## Scope
- 3 machines: sweetpea, qwerty, sauron
- Config file tracking via bare git repos on each machine (read-only snapshots on NixOS)
- Official documentation in `docs/` (current deployed state, not experiments)
- Zettelkasten `Inside/Projects/Homelab/` remains a learning log only — not authoritative

---

## Implementation plan

### Phase 1 — Scaffold (complete)
- [x] Create `~/Repositories/self-hosted/homelab/` directory structure
- [x] Write `homelab/CONTEXT.md` and `Raymer/CONTEXT.md`
- [x] Create placeholder dirs: `docs/`, `sweetpea/`, `qwerty/`, `sauron/`
- [x] Capture sessions in `memory/2026-04-02.md`

### Phase 2 — Config tracking (not started)
Set up a bare git repo on each machine to snapshot `/etc/` config files.

**Per-machine setup (repeat for sweetpea, qwerty, sauron):**
```bash
# On the homelab machine:
git init --bare ~/.homelab-configs

# Add to ~/.bashrc:
alias hc='git --git-dir="$HOME/.homelab-configs/" --work-tree="/"'

# Stage and commit relevant config files, e.g.:
hc add /etc/nginx/nginx.conf /etc/nginx/sites-enabled/
hc add /etc/dnsmasq.conf
hc ci -m "initial config snapshot"

# Push to local git server (or GitHub)
hc remote add origin <url>
hc push -u origin main
```

**On NixOS — clone each repo into its placeholder dir:**
```bash
git clone <sweetpea-repo-url> ~/Repositories/self-hosted/homelab/Raymer/sweetpea
git clone <qwerty-repo-url>   ~/Repositories/self-hosted/homelab/Raymer/qwerty
git clone <sauron-repo-url>   ~/Repositories/self-hosted/homelab/Raymer/sauron
```

**To update a snapshot:**
```bash
git -C ~/Repositories/self-hosted/homelab/Raymer/sweetpea pull
```

Priority order: sweetpea first (DNS/DHCP/nginx — most infrastructure-critical), then qwerty, then sauron.

### Phase 3 — Documentation (not started)
Populate `docs/` with official documentation for each machine.
Suggested starting structure:
```
docs/
├── sweetpea.md     ← nginx vhosts, dnsmasq config overview, DHCP leases approach
├── qwerty.md       ← docker-compose services, NAS mount setup, storage layout
└── sauron.md       ← WoL setup, AI workload notes
```

---

## Open decisions
- Where to host the bare git repos (local git server vs. GitHub private repos)?
- Should `hc` alias be the same across all machines or machine-specific?
- Which specific config files to track per machine (decide per-machine when setting up Phase 2)

---

## Related
- Session notes: `memory/2026-04-02.md`
- Machine details: `Raymer/CONTEXT.md`
- Learning log (not authoritative): zettelkasten `Inside/Projects/Homelab/`
