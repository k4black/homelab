# TODO

Open items from the 2026-10-01 review. Nothing is committed yet — all changes are
in the working tree.

## Blocking

- **VPS (hetzner, 65.109.133.99) is unreachable.** `ssh hetzner` fails with a
  changed host key (`known_hosts:31`) and `Permission denied (publickey)`. The
  host appears rebuilt or replaced. `playbook_vps.yml` cannot deploy until this
  is resolved: confirm the machine, fix the known_hosts entry, re-assert the key,
  then re-run the playbook (the vps tag bumps are staged and untested).
- **pi5 static hostname drift.** `hostnamectl` reports static hostname `homelab`
  and pretty hostname `pi5`. `vars/pi5.yml` sets `device_name: pi5` and
  `roles/linux_server_setup/tasks/net.yml` writes it, so a full pi5 run should
  converge back to `pi5`. Decide which name is wanted before running it.

## Verify after the next pi5 deploy

- **Pi-hole now reads `/etc/dnsmasq.d`.** Both pihole blocks gained
  `FTLCONF_misc_etc_dnsmasq_d: 'true'`; without it Pi-hole v6 ignores the mounted
  `02-custom-dns.conf` (split-horizon `pi5.<domain>` on pi5, `cname` entries on
  vps). Confirm the entries resolve after the deploy.
- **Hermes dashboard auth.** The dashboard now needs basic auth
  (`HERMES_DASHBOARD_BASIC_AUTH_*`). Check `docker exec hermes hermes config check`
  and that `http://<pi5>:9119` prompts for credentials.
- **FlareSolverr healthcheck** changed from `wget` (absent in the image) to
  `curl -fsS http://localhost:8191/health`; it should leave "unhealthy" behind.
- **Jellyfin 10.11.11, homepage v2.4.0, prowlarr 2.6.5, radarr 6.4.4,
  sonarr 4.0.20, glances 4.5.7, netdata v2.12.0, tailscale v1.102.5**: smoke-test
  the UIs after the deploy. The *arr apps will show a new cosmetic "Allowed Hosts
  is not configured" warning (accept-any-host is still the runtime behaviour).
- **`homepage-logs` is no longer mounted.** `LOG_PATH` was never read by
  homepage; logs go to `/app/config/logs/homepage.log`. The old
  `/srv/data/homepage-logs` directory can be deleted.

## Follow-ups

- **Jellyfin 12.1 migration.** 10.11.11 is the last release of the 10.11 line and
  is security-fixed, but no longer maintained. 12.1 is stable and needs: `/config`
  backup, third-party plugin removal before the upgrade, a mandatory full library
  scan, and current clients (legacy `/emby/*` routes and legacy authorization are
  gone). Do it as a deliberate change window, not a tag swap.
- **filebrowser v2.63.23 is the final release** (repo archived 2026-09-01). The
  bump fixes known advisories, but the project is EOL; the maintained fork
  (FileBrowser Quantum) is a different product with its own config/DB, so plan a
  migration rather than a tag swap. Also check for symlinks escaping the served
  scope — from 2.63.16 they are not followed unless
  `FB_FOLLOW_EXTERNAL_SYMLINKS=true`.
- **Pi-hole `adlists.list` is legacy** (pre-v5): the pi5/vps playbooks still copy
  it, and v6 reads ad-lists from `gravity.db`. Either manage the list through the
  API or drop the file.
- **homepage is publicly routed with no auth** (`HOMEPAGE_ALLOWED_HOSTS: "*"`).
  v2.2.0 fixed GHSA-669x-4pg4-w24r (widget proxy abuse when auth is disabled),
  which is the main reason to be on v2.4.0. Consider enabling v2 auth.
- **hex is not installable yet.** k4black/hex has no release and hex-cli is on
  neither PyPI nor crates.io. Add a pinned entry to `agents_setup_brew_formulae`
  once it is published; until then `.agents` install.sh errors when hex is missing.
- **CI still needs a full run.** The MacBook jobs now clone k4black/.dotfiles and
  k4black/.agents over HTTPS, so the run continues into `agents_setup`, whose
  install.sh wires harnesses and may need `claude`/`codex` auth that CI lacks.
  Watch the next workflow run.
- **Mac Homebrew is behind**: 30 formulae and 12 casks (`git`, `gh`,
  `pi-coding-agent` 0.87.1 → 0.99.1, `ungoogled-chromium` 152 → 154,
  `docker-desktop`, `claude-code`, `codex`, `notion`, `zotero`). The playbook
  never upgrades by design; run `brew upgrade` by hand.
- **timemachine is pinned to `smb-20261001`.** The upstream tag is rebuilt daily;
  re-pin when a new base image matters.
- **README references a playbook that does not exist.** The router section tells
  you to run `playbook_router.yml --tags=generate`, but the repo has only
  `playbook_macbook.yml`, `playbook_pi5.yml` and `playbook_vps.yml`. Either add
  the router playbook back or move that section to the pi5/vps docs.
