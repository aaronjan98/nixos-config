# LANtern UI Spec

**Status:** planned — not yet implemented
**Stack:** React + Vite · shadcn/ui · Recharts · Tailwind CSS · FastAPI backend
**Theme:** Dark

Decided 2026-06-07. User knows React, not HTMX — React chosen over HTMX because
the LLM streaming interface (the project's differentiator) is much cleaner in React,
and shadcn/ui provides dark-themed portfolio-quality components out of the box.

---

## Guiding principles

- **Device-first.** Every piece of data is navigable back to the device that generated it.
- **No page refreshes.** Data updates in place via React polling or SSE.
- **One-click depth.** Surface summaries everywhere; drill into detail with one click.
- **The LLM box is always reachable.** Query input lives in the nav, not buried on a page.

---

## Repo structure additions (inside `~/Repositories/self-hosted/lantern/`)

```
lantern/
├── api/                     ← FastAPI backend (new)
│   ├── main.py              ← app + CORS + router registration
│   ├── db.py                ← SQLite connection helper (read-only)
│   └── routes/
│       ├── stats.py
│       ├── devices.py
│       ├── dns.py
│       ├── flows.py
│       └── query.py         ← LLM interface (Phase 2)
├── ui/                      ← React + Vite frontend (new)
│   ├── index.html
│   ├── vite.config.ts
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx          ← router, layout, nav
│   │   ├── components/
│   │   │   ├── StatCard.tsx
│   │   │   ├── DeviceTable.tsx
│   │   │   ├── QueryFeed.tsx
│   │   │   ├── TopDomainsChart.tsx
│   │   │   └── FlowTable.tsx
│   │   └── pages/
│   │       ├── Overview.tsx
│   │       ├── Devices.tsx
│   │       ├── DeviceDetail.tsx
│   │       ├── DNS.tsx
│   │       └── Flows.tsx
│   └── package.json
├── Dockerfile.api           ← new: FastAPI image
├── Dockerfile.ui            ← new: nginx serving Vite build
└── docker-compose.yml       ← updated to add api + ui services
```

The existing `lantern/`, `bin/`, and `Dockerfile` (collectors) are unchanged.

---

## Pages

### 1. Overview (`/`)

Landing page. Answers "what is my network doing right now?"

**Stat cards (top row):**
- Active devices (seen in last 5 min)
- DNS queries today
- Top domain last hour (with count)
- Total bytes transferred today (from netflow)

**Charts:**
- DNS queries over time — line chart, last 24h, 1-hour buckets (Recharts)
- Top 10 domains — horizontal bar chart, last hour

**Activity feed:**
- Last 20 DNS queries, auto-refreshing every 5s
- Columns: time · device hostname/IP · domain · query type

---

### 2. Devices (`/devices`)

Table of every device LANtern has seen.

**Columns:**
- Status dot (green = seen last 5 min, grey = offline)
- Hostname (or MAC if none)
- IP address
- Vendor (OUI lookup)
- First seen / last seen
- DNS queries last 24h

**Interactions:**
- Click row → Device Detail
- Search/filter by hostname, IP, or vendor
- Sort by any column

---

### 3. Device Detail (`/devices/:mac`)

Everything about one device.

**Header:** hostname · MAC · vendor · current IP · first/last seen

**Sections:**
- IP history — timeline of IP assignments from lease_observations
- DNS activity — line chart (queries/hour, last 24h) + recent query feed
- Top domains — bar chart (configurable window)
- Traffic flows — recent flows where device is src or dst

---

### 4. DNS (`/dns`)

Raw query log with filtering and aggregation.

**Controls:** device filter · time window (1h/6h/24h/7d) · query type filter (A/AAAA/all)

**Tabs:**
- Feed — live query log, newest first
- Top domains — bar chart + table by query count
- Clients — which devices are most active

---

### 5. Flows (`/flows`)

NetFlow traffic from the router.

**Table columns:** time · src IP:port · dst IP:port · protocol (resolved) · packets · bytes · duration

**Top talkers panel:** top src IPs by bytes · top dst IPs by bytes (last hour)

**Controls:** host filter · time window

---

### 6. Query bar — nav (Phase 2)

Persistent input in the top navigation bar.

- Text field: "Ask anything about your network..."
- POST to `/api/query` → SSE stream, renders token-by-token in modal/drawer
- Last 5 queries stored in localStorage

---

## API endpoints (FastAPI, read-only against lantern.db)

| Method | Path | Params | Returns |
|--------|------|--------|---------|
| GET | `/api/stats` | — | counts, active device count, today's query count |
| GET | `/api/devices` | — | all devices sorted by last_seen desc |
| GET | `/api/devices/{mac}` | — | device + IP history |
| GET | `/api/dns/recent` | `limit`, `client_ip` | recent dns_queries |
| GET | `/api/dns/top` | `minutes`, `limit` | top domains |
| GET | `/api/dns/clients` | `minutes` | per-device query counts |
| GET | `/api/flows/recent` | `limit`, `host` | recent netflow_records |
| GET | `/api/flows/top-talkers` | `minutes` | top src/dst IPs by bytes |
| POST | `/api/query` | body: `{question}` | SSE stream (Phase 2) |

---

## docker-compose additions

```yaml
api:
  build:
    context: .
    dockerfile: Dockerfile.api
  restart: unless-stopped
  ports:
    - "8000:8000"
  volumes:
    - lantern_data:/var/lib/lantern:ro

ui:
  build:
    context: .
    dockerfile: Dockerfile.ui
  restart: unless-stopped
  ports:
    - "3000:80"
  depends_on:
    - api
```

In development: `vite dev` proxies `/api/*` → `localhost:8000`.
In production: nginx serves the Vite build, proxies `/api/*` to the api container.

---

## Out of scope for this spec

- Authentication — deferred; LANtern is LAN-only for now
- Alerts / push notifications — Phase 3
- LLM implementation details — separate spec when Phase 2 starts
- Long-term qwerty/TimescaleDB integration — separate architectural decision
