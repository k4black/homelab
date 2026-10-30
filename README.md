# Personal infrastructure (Ansible)

[![Test playbooks](https://github.com/k4black/personal-infra/actions/workflows/test.yml/badge.svg)](https://github.com/k4black/personal-infra/actions/workflows/test.yml)

Ansible playbooks for the MacBooks, the Raspberry Pi 5 (`pi5`) and the VPS.

Related repos, cloned next to this one into `~/Projects/personal/` by the MacBook playbook:

| Repo | Owns |
|---|---|
| [k4black/.dotfiles](https://github.com/k4black/.dotfiles) | zsh, git, ssh client config, `.macos.sh` |
| [k4black/.agents](https://github.com/k4black/.agents) | agent skills, rules, `install.sh` |

This repo installs every binary. `.agents/install.sh` only wires config.
The MacBook playbook updates clean `.agents` checkouts. It preserves local changes,
skips the repository update, and runs the local `install.sh` when changes exist.


## Setup

### Controller (a Mac)

Use Homebrew Python 3.13 instead of the macOS system Python.
Install Ansible Core 2.22 or newer. Collections come from `requirements.yml`.
Finish the Command Line Tools installation before the remaining commands.

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"  # Intel Macs: use /usr/local/bin/brew
brew install python@3.13
"$(brew --prefix python@3.13)/bin/python3.13" -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
ansible-galaxy install -r requirements.yml --force
```

Complete the Secrets and SSH keys steps below. Then run the MacBook command under **Run**.

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

1. Install Bitwarden from the Mac App Store, open it, log in, and unlock the vault.
   On a new Mac you can install the App Store apps first with
   `ansible-playbook playbook_macbook.yml -e device_name=[DEVICE_NAME] --tags mas --ask-become-pass`.
2. In Bitwarden Settings, turn on **Enable SSH agent**. Set **Ask for authorization
   when using SSH agent** to **Never** for unattended playbook runs, or approve
   Bitwarden's authorization prompt when it appears.
3. Add SSH key items to the vault, named like their files: `id_ed25519`,
   `id_ed25519_i7`, `id_rsa`. Register the corresponding public key in GitHub
   Settings -> SSH and GPG keys.
4. Verify the agent and GitHub connection:

   ```bash
   export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
   ssh-add -l
   ssh -o "IdentityAgent=$SSH_AUTH_SOCK" -T git@github.com
   ```

   For a new GitHub host key, verify the fingerprint against
   [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
   before accepting. Successful GitHub authentication exits with status 1 because
   GitHub does not provide shell access. A host-key verification failure is a
   separate issue from an inactive agent; investigate changed keys before replacing them.

The full playbook checks the agent and GitHub authentication before provisioning
and stops with setup instructions if either check fails. Bitwarden must stay
running and unlocked; opening it at login does not unlock the vault.
See [Bitwarden's SSH agent setup](https://bitwarden.com/help/ssh-agent/).

The playbook writes `~/.ssh/<item>.pub` from the agent before GitHub validation
and repository clones, plus `~/.ssh/config.d/homelab`. The GitHub configuration
selects `id_ed25519`, so that Bitwarden key item must be named `id_ed25519`.
Its public file lets SSH select the agent key without a local private key.
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
ansible-playbook playbook_macbook.yml -e device_name=k4pro-i7 --ask-become-pass
ansible-playbook playbook_macbook.yml -e device_name=k4pro-m3 -e macbook_profile=work --ask-become-pass
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
  or a profile name. The playbook clears and rebuilds pinned items when they differ
  from that list, and shows recent apps. Other custom pins and folder stacks are removed.
  The Dock role applies its restart before later roles run. A later failure cannot
  leave the displayed Dock out of date.
  Downloads remains beside Trash as a grid folder, sorted by date added.
  The role validates app paths and writes native file-URL tiles in one update.
- macOS preferences: `.macos.sh` in `.dotfiles`, run on every MacBook playbook run.
  User preferences run without sudo. A separate `--system-only` invocation sets
  system preferences, including Low Power Mode on battery and normal mode on AC.
  The script shows battery percentage and hides Siri and Now Playing.
  The Dock sits on the right with 40-pixel icons.
- Homebrew: the playbook installs, never upgrades. Run `brew upgrade` by hand.
- Open at login: Bitwarden, MonitorControl, and Caffeine, configured through
  `macbook_login_apps` in `vars/macbook.yml`. Allow System Events automation if
  macOS prompts while the playbook adds these login items.

The playbook configures `.dotfiles` and clones `.agents` after the command line
tools step, before application installation. Agent harness configuration runs
after its required binaries are installed. Both repository checkouts preserve local changes.

### Lint and CI

```bash
yamllint . && ansible-lint
```

`.github/workflows/test.yml` lints, runs each playbook with `testing=true` plus an
idempotence check, and checks the Tailscale OAuth client. Jobs with secrets wait for
approval of the `bws` environment.

The macOS job runs `python tests/check_dock_restart.py` after provisioning.
This check applies the personal Dock layout and verifies its restart before a simulated later failure.
