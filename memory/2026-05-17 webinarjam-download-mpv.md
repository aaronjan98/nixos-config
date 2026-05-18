# 2026-05-17 — WebinarJam video download + mpv install

## What was worked on
- Downloaded a WebinarJam webinar replay (~773MB, 720p) to ~/Downloads as `probate-webinar.mp4`
- Added `mpv` to nixos-config user packages
- Shared the video via Nextcloud public link

## Key findings

**WebinarJam replay requires authenticated cookies.**
The replay URL redirects to a login page. Browser extension cookie exports miss HttpOnly cookies (session token), so they don't work. The video URL itself is embedded in the page source as a direct Vimeo progressive MP4.

**Workaround that worked:**
1. Export cookies with the "HTTP Only Cookies" Firefox extension (exports HttpOnly cookies unlike standard cookie exporters)
2. Fetch the page with curl + cookies to extract the direct video URL from the page JS (`videoUrl` field in the `replay:` config object)
3. Download the direct Vimeo URL with yt-dlp using `-o <filename>` (filename must be explicit — the auto-generated name from the CDN token URL is too long for the filesystem)

**yt-dlp on NixOS:** `nix shell nixpkgs#yt-dlp --command yt-dlp ...`

## Changes made
- Added `mpv` to `users.users.aj.packages` in `hosts/thinkpad-t14/configuration.nix`

## Sharing via Nextcloud
- Uploaded to Nextcloud at cloud.janovitch.com
- Public share link (no login required for recipient): Files → right-click → Share → Share link → copy URL
- Format: `https://cloud.janovitch.com/s/XXXXXXXXXX`

## Open questions / next steps
- Run `sudo nixos-rebuild switch` to activate mpv
