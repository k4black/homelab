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

### Hermes (pi5)

Store in BWS: `hermes_openrouter_api_key` ([OpenRouter](https://openrouter.ai/keys)),
`hermes_telegram_bot_token` ([@BotFather](https://t.me/BotFather) `/newbot`),
`hermes_telegram_allowed_users` (your ID from [@userinfobot](https://t.me/userinfobot)),
`hermes_dashboard_password`, `hermes_dashboard_auth_secret`, `todoist_api_token`.

- Chat: message the bot in Telegram.
- Dashboard: `http://[PI5_IP]:9119` or `http://pi5.[TAILNET].ts.net:9119`, basic auth.

### Anki (pi5), one-time AnkiWeb login

1. Set `QT_QPA_PLATFORM: vnc` and publish `5900` on the `anki` service, deploy.
2. Connect a VNC client to `vnc://[PI5_IP]:5900`, log into AnkiWeb, "Download from AnkiWeb".
3. Set `QT_QPA_PLATFORM: offscreen`, remove the `5900` publish, deploy.

### Tailscale

Create an OAuth client with the `auth_keys` write scope and tag `tag:node`, and store
`tailscale_oauth_client_id` / `tailscale_oauth_client_secret` in BWS. The playbooks
mint a one-off tagged key per new node. In the admin console, check that each node
shows "key expiry disabled".


## Run

```bash
ansible-playbook playbook_macbook.yml -e device_name=k4pro-i7
ansible-playbook playbook_macbook.yml -e device_name=k4pro-m3 -e macbook_profile=work
ansible-playbook playbook_pi5.yml
ansible-playbook playbook_vps.yml
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
