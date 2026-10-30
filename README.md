# Personal infrastructure (Ansible)

[![Test playbooks](https://github.com/k4black/personal-infra/actions/workflows/test.yml/badge.svg)](https://github.com/k4black/personal-infra/actions/workflows/test.yml)

Ansible playbooks for the MacBooks, the Raspberry Pi 5 (`pi5`) and the VPS.

Related repos, cloned next to this one into `~/Projects/personal/` by the MacBook playbook:

| Repo | Owns |
|---|---|
| [k4black/.dotfiles](https://github.com/k4black/.dotfiles) | zsh, git, ssh client config, `.macos.sh` |
| [k4black/.agents](https://github.com/k4black/.agents) | agent skills, rules, `install.sh` |

This repo installs every binary. `.agents/install.sh` only wires config.


## Setup

### Controller (a Mac)

```bash
xcode-select --install
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
ansible-galaxy install -r requirements.yml --force
```

### Secrets (Bitwarden Secrets Manager)

Every secret and private identifier lives in Bitwarden Secrets Manager (BWS),
project `homelab`. Playbooks load it with `tasks/bws_load.yml`; `bws` installs itself.

Once per Bitwarden account:
1. Secrets Manager: create the organization and the project `homelab`.
2. Machine account `operator`: "Can read" on `homelab`. Create an access token and
   save it as a Bitwarden vault item.
3. GitHub -> Settings -> Environments -> `bws`: required reviewer = you, secret
   `BWS_ACCESS_TOKEN` = a token that can read `homelab`.

Once per Mac:
```bash
security add-generic-password -s bws-homelab -a "$USER" -w   # paste the token
```

### SSH keys (Bitwarden SSH agent)

1. Install Bitwarden from the App Store (the MacBook playbook does it via `mas`) and log in.
2. Settings -> "Enable SSH agent", authorization prompt "Never".
3. SSH key items are named like their files: `id_ed25519`, `id_ed25519_i7`, `id_rsa`.

The playbook writes `~/.ssh/<item>.pub` from the agent and `~/.ssh/config.d/homelab`.
On a new Mac, run the MacBook playbook first: the pi5 and vps playbooks read `~/.ssh/id_ed25519.pub`.
`~/.ssh/config` comes from `.dotfiles`.

### pi5

1. Flash Raspberry Pi OS Lite with the Raspberry Pi Imager: Wi-Fi, SSH, your public key.
2. Storage disk: get its UUID with `sudo blkid` and set `storage_disk_uuid` in `vars/pi5.yml`.
3. Router (FRITZ!Box):
   - Home Network -> Network -> pi5: "Always assign this network device the same IPv4 address".
   - Internet -> Account Information -> DNS Server: both fields = the pi5 IP, allow fallback to public DNS.
   - Internet -> Permit Access -> Port Sharing: TCP `pi5_ssh_port` to pi5.
   - Internet -> Permit Access -> DynDNS: update URL
     `https://www.duckdns.org/update?domains=[DOMAIN]&token=[TOKEN]&ip=<ipaddr>&ipv6=<ip6addr>`.
4. Run the pi5 playbook.

### Router (GL.iNet, draft)

`playbook_router.yml` is a draft and has not run on a device yet. It replaces the
FRITZ!Box steps above: static lease and port forward for the pi5, AdGuard Home as
the LAN resolver, Tailscale subnet router + exit node. Store `pi5_mac_address` in BWS.
Add the router's ssh public key under System -> Administration before the first run.

### Hermes (pi5)

Store in BWS: `hermes_openrouter_api_key` ([OpenRouter](https://openrouter.ai/keys)),
`hermes_telegram_bot_token` ([@BotFather](https://t.me/BotFather) `/newbot`),
`hermes_telegram_allowed_users` (your ID from [@userinfobot](https://t.me/userinfobot)),
`hermes_dashboard_password`, `hermes_dashboard_auth_secret`, `todoist_api_token`.

- Chat: message the bot in Telegram.
- Dashboard: `https://hermes.pi5.[DOMAIN]`, basic auth.

### Anki (pi5), one-time AnkiWeb login

1. Set `QT_QPA_PLATFORM: vnc` and publish `5900` on the `anki` service, deploy.
2. Connect a VNC client to `vnc://[PI5_IP]:5900`, log into AnkiWeb, "Download from AnkiWeb".
3. Set `QT_QPA_PLATFORM: offscreen`, remove the `5900` publish, deploy.

### Tailscale

Two OAuth clients, both in BWS:
- `tailscale_policy_oauth_client_id` / `_secret`: scope `policy_file`, used only by
  `playbook_tailscale_policy.yml` (`--check` shows the diff, without it validates and applies
  `files/tailscale-policy.hujson.j2`). Push the policy first: it defines the tag owners.
- `tailscale_oauth_client_id` / `_secret`: scope `auth_keys`, owns `tag:server` and `tag:router`
  (keep `tag:node` until every node has re-joined). The playbooks mint a one-off tagged key per node.

By hand in the admin console: DNS -> Nameservers -> Add nameserver -> Custom, one per server
(pi5, vps) with its tailnet IP, "Restrict to domain" = `[DOMAIN]`. Every server runs a
`tailnet-dns` resolver on its tailnet IP that answers `*.<host>.[DOMAIN]` with that host's tailnet IP.

### Auth (Authelia on the vps)

One login for the public door `https://auth.vps.[DOMAIN]`. Clients on the tailnet, a LAN
behind a pi5, or a docker bridge see no login. Store in BWS:
- Random (`openssl rand -hex 32`): `authelia_jwt_secret`, `authelia_session_secret`,
  `authelia_storage_encryption_key`, `authelia_oidc_hmac_secret`.
- `authelia_oidc_jwks_key`: `openssl genrsa 4096`, the whole PEM.
- `authelia_users`: JSON list `[{"username": "...", "displayname": "...", "email": "...",
  "password": "<hash>", "groups": ["admins"]}]`. Hash:
  `docker run --rm authelia/authelia:4.39.28 authelia crypto hash generate argon2 --password '...'`.
- OIDC clients, two values each from one command
  `docker run --rm authelia/authelia:4.39.28 authelia crypto hash generate pbkdf2 --random --random.length 64 --random.charset alphanumeric`:
  `authelia_oidc_jellyfin_secret` (the password) + `authelia_oidc_jellyfin_secret_hash` (the digest),
  same for `authelia_oidc_homeassistant_*`.

Second factor: each user enrols a passkey or TOTP on first login. Identity mails land in
`/srv/data/authelia/notification.txt` on the vps; pass the link on.

### How requests flow

- Public: `svc.<host>.[DOMAIN]` -> vps IP -> vps Traefik (Authelia) -> local service, or the
  other host's Traefik over the tailnet.
- Tailnet: split DNS -> that host's tailnet IP -> its Traefik, no login.
- LAN: Pi-hole answers every `svc.<host>.[DOMAIN]` with the local pi5, whose Traefik forwards
  remote hosts over the tailnet, no login.
- Container ports are not published; use the names. The firewall only opens 80/443/53/ssh.

## Run

```bash
ansible-playbook playbook_macbook.yml -e device_name=k4pro-i7
ansible-playbook playbook_macbook.yml -e device_name=k4pro-m3 -e macbook_profile=work
ansible-playbook playbook_pi5.yml
ansible-playbook playbook_vps.yml
ansible-playbook playbook_tailscale_policy.yml --check   # diff; drop --check to apply
```

Containers only (configs + `docker compose up`):
```bash
ansible-playbook playbook_pi5.yml --tags docker
ansible-playbook playbook_vps.yml --tags docker
```


## Maintenance

### Add or change a secret

1. BWS -> project `homelab` -> New secret. Name it like the Ansible var (`snake_case`);
   prefix host-only ones (`pi5_...`, `vps_...`).
2. Reference it in `vars/all.yml` or `vars/<host>.yml`: `my_token: "{{ bws.my_token }}"`.
3. Container env var: add `MY_TOKEN='{{ my_token }}'` to `files/<host>/compose.env.j2`
   and `MY_TOKEN: ${MY_TOKEN}` to `docker-compose.yml.j2`. Never put a value in the compose file.

Rotate: change the value in BWS and rerun the playbook.
BWS names that differ from the var: `base_domain` -> `domain`, `personal_email` -> `email`,
`pi5_password` / `vps_password` -> `password`.
Private identifiers live there too: `pi5_tailscale_ipv4`, `vps_tailscale_ipv4` (empty
until the vps rejoins the tailnet), `pi5_mac_address`.

### Add a service or a host

- Service: a container with Traefik labels (`svc.<host>.[DOMAIN]`, `websecure`, `certresolver=cf`,
  on the vps also `middlewares=authelia@file`) and Homepage labels (`homepage.group`, `href`).
  No published port. Every Homepage shows it on the next run.
- Host: an entry in `homelab_hosts` (`vars/all.yml`) with its tailnet IP in BWS, a
  `vars/<host>.yml` with `homelab_host`, `tailscale_tag`, `lan_subnet`, and the split DNS entry.

### Hermes

- Model: `default:` in `files/pi5/hermes-config.yaml.j2` (an OpenRouter model id).
- Image tag: pinned in `files/pi5/docker-compose.yml.j2`.
- Skill changes: Hermes sends a diff in Telegram. Apply it in `../.agents` with
  `git apply`, commit, push. The pi5 clone pulls daily.

### MacBook

- Profile: `macbook_profile` = `personal` (default) or `work`; see `vars/macbook.yml`.
- Dock: `dockitems_persist_layout` in `vars/macbook.yml`, each entry with `profile: all`
  or a profile name.
- macOS preferences: `.macos.sh` in `.dotfiles`, run on every MacBook playbook run.
- Homebrew: the playbook installs, never upgrades. Run `brew upgrade` by hand.

### Lint and CI

```bash
yamllint . && ansible-lint
```

`.github/workflows/test.yml` lints, runs each playbook with `testing=true` plus an
idempotence check, and checks the Tailscale OAuth client. Jobs with secrets wait for
approval of the `bws` environment.
