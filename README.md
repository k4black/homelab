# Personal Infrastructure Setup with Ansible

[![Test playbooks](https://github.com/k4black/personal-infra/actions/workflows/test.yml/badge.svg)](https://github.com/k4black/personal-infra/actions/workflows/test.yml)

This repository contains Ansible playbooks to set up a personal MacBook and home server. 
This README provides instructions on how to customize variables and run the playbooks.


## Prerequisites

Install [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) on your local machine.
```bash
python -m pip install ansible
```


## Configuration

Before running the playbook, you need to set the desired variables in `group_vars/*` files.
Also be sure to set up `inventory.ini` with the correct IP addresses of your hosts.


## Running the Playbook

Install command line tools to get git
```bash
xcode-select –-install
```

Create env and install ansible
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Update the roles
```bash
ansible-galaxy install -r requirements.yml --force
```

To run the playbooks, execute the following command:
```bash
ansible-playbook playbook_macbook.yml -e device_name=k4pro-i7 --ask-become-pass
ansible-playbook playbook_macbook.yml -e macbook_profile=work -e device_name=k4pro-m3 --ask-become-pass
ansible-playbook playbook_pi5.yml --ask-become-pass
ansible-playbook playbook_vps.yml
```

Fast docker-only update (skip packages, security, SSH setup — only deploy configs and restart containers):
```bash
ansible-playbook playbook_pi5.yml --tags docker --ask-become-pass
ansible-playbook playbook_vps.yml --tags docker
```




1. create vault password file `.vault_pass.txt`
2. to encrypt smth `ansible-vault encrypt_string --stdin-name mas_email`
3. to decrypt `ansible-vault decrypt_string --stdin-name mas_email`
4. to run `ansible-playbook -i inventory.ini playbook_macbook.yml`
5. to run `ansible-playbook -i inventory.ini playbook_vps.yml`

To lint run `yamllint .` and `ansible-lint`


## pi5 setup

### General

Create duckdns [DOMAIN] and [TOKEN]

### Backups 

Connect disk to the raspberry pi and get uuid (PARTUUID)
```bash
sudo blkid
```
update vars/pi5.yml

### Pi initial setup:

1. Install raspbian lite on raspberry pi  
    Easy way: use [raspberry pi imager](https://www.raspberrypi.org/software/)  
    Fill wi-fi credentials and enable ssh with your ssh key
2. Create ssh config for the pi5 with key and `pi5` announced name
3. Run `ansible-playbook -i inventory.ini playbook_pi5.yml` to setup pi5


### Router setup:

1. Connect raspberry pi to the power (auto network connection)
2. Fix ip address in router settings  
    Home Network -> Network -> Network Connections -> Edit pi5 -- "Always assign this network device the same IPv4 address"
3. Announce pi5 as upstream dns server in router settings
    Internet -> Account Information -> DNS Server -> Use other DNSv4/DNSv6 Servers  
    * Fill both fields with raspberry pi ip address
    * Checkbox fallback to public dns 
4. Forward vpn subnet through pi5
    Home Network -> Network -> Network Settings -> IPv4 Addresses -> Network Settings -> IPv4 Routes -> New IPv4 Route  
   (same as in vars/all.yml)
    ```
    IPv4 Network: 10.1.0.0
    Subnet Mask: 255.255.255.0  (/24)
    Gateway: [pi5 fixed ip]
    Ipv4 route active: checked
    ```
5. Forward ports to pi5
    Internet -> Permit Access -> Port Sharing -> New Port Sharing Rule
    Device: pi5
    New Sharing -> Port Sharing
    ```
    Application: Custom
    Service Name: Wireguard
    Protocol: UPD
    Port: 51820
    ```
    ```
    Application: Custom
    Service Name: SSH
    Protocol: TCP
    Port: 4221
    ```

### Hermes Agent

Self-hosted [Hermes Agent](https://github.com/NousResearch/hermes-agent) gateway
(stock `nousresearch/hermes-agent` image, arm64). One container runs both the
agent gateway and the web dashboard. LLM calls go through OpenRouter.

Config lives in the shared `vars/all.yml` (not pi5-specific) so the gateway can
move to / be added on another node later:
1. OpenRouter key — create at https://openrouter.ai/keys, then
   `ansible-vault encrypt_string --stdin-name hermes_openrouter_api_key` and paste
   the result over `hermes_openrouter_api_key`.
2. Telegram bot — `/newbot` via [@BotFather](https://t.me/BotFather), then
   `ansible-vault encrypt_string --stdin-name hermes_telegram_bot_token`.
3. Your Telegram user ID — message [@userinfobot](https://t.me/userinfobot) and
   put the number in `hermes_telegram_allowed_users` (comma-separated for several).

Access after deploy (host:port, like the other services — no DNS route):
* Telegram — message your bot (only `hermes_telegram_allowed_users` may talk to it).
* Dashboard — `http://[PI5_IP]:9119` or `http://pi5.[tailnet].ts.net:9119`, no login
  (runs `--insecure`), reachable on LAN/Tailscale/VPN only.

Change the model by editing `default:` in `files/pi5/hermes-config.yaml.j2` (any
OpenRouter model id); the image tag is pinned inline in `docker-compose.yml.j2`.
The agent's shell tools run inside the container (`terminal.backend: local`); the
docker socket is intentionally not mounted. iCloud (`icloud-cli-tools`) is not
wired up yet — it would be a thin `FROM nousresearch/hermes-agent` + `pip install`
layer.

**Skills.** The 66 bundled skills are trimmed to a personal-assistant set via
`skills.disabled` in `hermes-config.yaml.j2` (no dev/mlops/heavy-creative). On top
of that, the personal skills repo [k4black/dotfiles](https://github.com/k4black/dotfiles)
is cloned to `/srv/data/hermes/skills-repo` (clone-if-missing) and loaded via
`skills.external_dirs` (`plugins/personal/skills`). Hermes can read, edit/author,
and **git-push** those skills: a fine-grained PAT (`hermes_github_pat`, scoped to
`k4black/dotfiles`, Contents R/W) is exposed as `GITHUB_TOKEN` and wired into the
container's `~/.gitconfig` credential helper. Set it once:
`ansible-vault encrypt_string --stdin-name hermes_github_pat`. The `github-auth`,
`github-repo-management`, `github-pr-workflow`, and `hermes-agent-skill-authoring`
skills are kept enabled for this. Note: `apple-notes`/`apple-reminders` are
macOS-only (won't run in the Linux container) and `anki-connect` needs a reachable
AnkiConnect — see below.

**MCP.** Todoist is wired in via the official [`@doist/todoist-mcp`](https://github.com/Doist/todoist-mcp)
as a stdio MCP server in `hermes-config.yaml.j2` (`mcp_servers.todoist`, run through the
image's `npx`), authenticated by the vaulted `todoist_api_token` (`TODOIST_API_KEY`).

**Anki.** Headless Anki + AnkiConnect API on `:8765`, **built locally** for arm64:
the playbook clones [ThisIsntTheWay/headless-anki](https://github.com/ThisIsntTheWay/headless-anki)
to `/srv/build/headless-anki` and builds it with a patched, arch-aware Dockerfile
(`files/pi5/anki.Dockerfile` → `Dockerfile.pi5`: official `anki-26.05-linux-aarch64`
on debian:13/glibc 2.41). The published `kaiimehra/headless-anki` arm64 image can't
run here — it's built on glibc 2.35, below Anki's 2.36 requirement. A named volume
seeds `/data` from the image's baked profile. Hermes reaches it at `http://anki:8765`
(set as `ANKI_CONNECT_URL` on the hermes service).
Runs headless and light (`QT_QPA_PLATFORM=vnc` only renders the single Anki window
on `:5900` while a viewer is connected — no desktop/X server, unlike a KasmVNC image).
AnkiWeb login (one-time): connect a **VNC client** (not a browser) to
`vnc://[PI5_IP]:5900` or `vnc://pi5.[tailnet].ts.net:5900` (no password; LAN/Tailscale-
gated), log into AnkiWeb in the Anki window, and choose "Download from AnkiWeb". Auth
persists in the `anki-data` volume; afterwards set `QT_QPA_PLATFORM=offscreen` and drop
the `5900` publish for zero VNC overhead. Also: the `anki-connect` skill hardcodes
`http://localhost:8765` — it needs a one-line change to read `ANKI_CONNECT_URL` (Hermes
can edit + push it).

### Remote access (without VPN)

After setup, you can SSH into the pi5 via DuckDNS hostname:
```bash
ssh k4black@[PI5_DOMAIN].duckdns.org -p 4221
```
This requires the SSH port forwarding (4221) configured above.


## router setup

### General

Create duckdns [DOMAIN] and [TOKEN]

### Generate config files

`ansible-playbook -i inventory.ini playbook_router.yml --tags=generate`

### VPN setup:

1. Setup DynDNS to update on the router
    Internet -> Permit Access -> DynDNS  
    ```
    Update URL: https://www.duckdns.org/update?domains=[DOMAIN]&token=[TOKEN]&ip=<ipaddr>&ipv6=<ip6addr>
    Domain Name: [DOMAIN].duckdns.org
    Username: none
    Password: [TOKEN]
    ```
2. Enable Wireguard on the router  
    Internet -> Permit Access -> VPN (WireGuard) -> Enable WireGuard -> Add connection  
    ```
    Connect networks or establish special connections
    already been set up: yes
    Name: wg0
    ```
    Load config from `.tmp/router-wg0.conf`
