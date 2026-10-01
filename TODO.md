# TODO

State after the 2026-10-01 review pass.

## Blocking

- **VPS (hetzner, 65.109.133.99) is unreachable.** `ssh hetzner` fails with a changed
  host key (`known_hosts:31`) and `Permission denied (publickey)`. `playbook_vps.yml`
  cannot deploy until this is resolved, so the vps image bumps and the new Tailscale
  mint flow are untested there.
- **pi5 static hostname drift.** `hostnamectl` reports static hostname `homelab` and
  pretty hostname `pi5`. `vars/pi5.yml` sets `device_name: pi5` and
  `roles/linux_server_setup/tasks/net.yml` writes it, so a full pi5 run converges back
  to `pi5`. Decide which name is wanted before running it.

## Tailscale

Nodes now join with a one-off, preauthorized auth key that the playbook mints from an
OAuth client holding only the `auth_keys` write scope and the `tag:node` tag
(`tasks/tailscale_mint_key.yml`). The OAuth secret stays in the vault.

Verified on pi5 (2026-10-01):

- OAuth token → one-off tagged key → an ephemeral test container joined the tailnet
  with `tags: ['tag:node']` and was removed cleanly.
- A read-only check of the live pi5 node reports `tags=['tag:node']`, so
  `tailscale_needs_key` is false and the playbook will neither mint nor convert it.

Open:

- **Kernel networking is live on pi5** (deployed 2026-10-01): `tailscale0` carries
  `100.72.254.6` and UFW allows `100.64.0.0/10`. SSH over the tailnet is still untested:
  no other tailnet peer is online (the Mac has no Tailscale, the vps is down).
- **`vps_tailscale_ipv4` is an empty placeholder** in `vars/all.yml`. Fill it once the vps
  rejoins the tailnet, otherwise the pi5 netdata stream (destination) and the four vps
  glances widgets on the homepage point nowhere. `pi5_tailscale_ipv4` is filled in.
- **Unverified: the "convert an existing user-owned node" branch** of
  `tasks/tailscale_mint_key.yml` (pi5 was already tagged, the vps is down), and the
  mint + compose path on a fresh host.
- **Revoke the old auth key.** Its `tailscale_authkey` vault entry was removed; the key
  itself still exists in the Tailscale admin console.
- `--advertise-exit-node` is still advertised by both nodes. Without ACL `autoApprovers`
  the first exit-node approval is manual.

## WireGuard removal (2026-10-01)

WireGuard is gone from the repo: macbook client configs, both server containers and their
`server-wg0.conf` templates, `files/router/`, the `vpn_network_*` vars, the `wireguard`
package entry, the 51820/udp open port and the firewall's VPN-subnet rule. Tailscale is
the replacement, which is why the tailnet subnet rule and kernel networking were added —
without them nothing outside the LAN could reach pi5/vps. Everything is in git history if
it has to come back. The router port-forwarding docs for WireGuard were removed too; the
pi5 SSH port forward (4221) stays.

Sources of the old wiring, for reference: the VPN subnet also carried netdata streaming
and the homepage vps widgets, now moved to `pi5_tailscale_ipv4` / `vps_tailscale_ipv4`.

## Verify after the next pi5 deploy

- **Pi-hole now reads `/etc/dnsmasq.d`** (`FTLCONF_misc_etc_dnsmasq_d: 'true'`); without
  it Pi-hole v6 ignores the mounted `02-custom-dns.conf`. Confirm the entries resolve.
- **Hermes dashboard auth.** Since hermes-agent v2026.9.24 a non-loopback dashboard bind
  requires an auth provider, so `HERMES_DASHBOARD_BASIC_AUTH_*` was added. Check
  `docker exec hermes hermes config check` and that `http://<pi5>:9119` prompts for
  credentials.
- **FlareSolverr healthcheck** changed to `curl -fsS http://localhost:8191/health`
  (`wget` is absent from the image); it should leave "unhealthy" behind.
- **Image bumps**: jellyfin 10.11.11, homepage v2.4.0, prowlarr 2.6.5, radarr 6.4.4,
  sonarr 4.0.20, glances 4.5.7, netdata v2.12.0, tailscale v1.102.5, traefik v3.7.13,
  pihole 2026.09.0, cloudflare-ddns 1.17.1, filebrowser v2.63.23, hermes v2026.9.24.
  The *arr apps show a new cosmetic "Allowed Hosts is not configured" warning;
  accept-any-host remains the behaviour.
- **`homepage-logs` is no longer created or mounted**; logs go to
  `/app/config/logs/homepage.log`. Delete the old `/srv/data/homepage-logs` directory.

## Follow-ups

- **Jellyfin 12.1 migration.** 10.11.11 is the security-fixed end of the 10.11 line. 12.1
  needs a `/config` backup, plugin removal before the upgrade, a mandatory full library
  scan, and current clients (legacy `/emby/*` routes and legacy authorization are gone).
- **filebrowser v2.63.23 is the final release** (repo archived 2026-09-01). Plan a
  migration to the maintained fork instead of future tag bumps. Check for symlinks
  escaping the served scope: since 2.63.16 they are not followed unless
  `FB_FOLLOW_EXTERNAL_SYMLINKS=true`.
- **Pi-hole `adlists.list` is legacy** (pre-v5); v6 reads ad-lists from `gravity.db`.
  Manage the list through the API or drop the file.
- **homepage is publicly routed with no auth** (`HOMEPAGE_ALLOWED_HOSTS: "*"`). v2.2.0
  fixed GHSA-669x-4pg4-w24r; consider enabling v2 auth.
- **hex is not installable yet** (no release; absent from PyPI/crates.io). Add a pinned
  entry once published; `.agents` install.sh links `../hex/skills` only when present.
- **pi5 Hermes skills clone moved** to `/srv/data/hermes/.agents`. After the next pi5
  deploy (done 2026-10-01), `/srv/data/hermes/agentic-tools` still holds uncommitted Hermes edits to `anki-connect/SKILL.md` that upstream does not have; merge or drop them, then remove it
  by hand. Turn on ZDR at https://openrouter.ai/settings/privacy (account-side only).
- **CI still needs a full green run.** The MacBook jobs now clone k4black/.dotfiles and
  k4black/.agents over HTTPS and skip the external scripts; the pi5/vps jobs skip
  docker-dependent verification via `run_docker`.
- **Mac Homebrew is behind**: 30 formulae and 12 casks. The playbook never upgrades by
  design; run `brew upgrade` by hand.
- **timemachine is pinned to `smb-20261001`**; re-pin when a new base image matters.
- **README references a playbook that does not exist**: the router section tells you to
  run `playbook_router.yml --tags=generate`, but the repo has only macbook/pi5/vps.
