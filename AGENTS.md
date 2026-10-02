# AGENTS.md

Ansible playbooks for the MacBooks, pi5 and VPS. Start with `README.md`. Open work lives as `TODO:` comments next to the code.

## Related repos

Changes here often touch two sibling repos. Edit them in place, each has its own git history:

- `../.dotfiles` — [k4black/.dotfiles](https://github.com/k4black/.dotfiles): zsh, git, `.macos.sh`. `~/.dotfiles` is a symlink to it.
- `../.agents` — [k4black/.agents](https://github.com/k4black/.agents): skills, `GLOBAL-AGENTS.md`, `install.sh`.

## Separation of concerns

- This repo installs every binary: agent CLIs (`roles/agents_setup`, `vars/macbook.yml` casks) and `jq`.
- `.agents/install.sh` installs no binaries. It fails on a missing CLI, then wires skills, rules, plugins, MCP servers and harness config.

## Public repo: no sensitive data

This repo and its CI logs are public. Git history keeps every commit forever.
Do not write these anywhere in the repo (code, comments, README, TODO, commit messages, PRs):

- Public IPs (e.g. the vps IP), home IP, router or ISP details.
- Real domain names, DuckDNS subdomains, tailnet name (`*.ts.net`). Use the BWS vars (`domain`, `pi5_duckdns_subdomain`, ...) or `[DOMAIN]` placeholders.
- Passwords, tokens, API keys, auth keys, private keys, even default or test ones. Put them in BWS, never as plaintext defaults.
- A list of which services have no auth, or other security findings. Keep audits out of the repo.

Before a commit, grep the diff for IPs, `*.ts.net`, domains and secret-looking strings.
CI must not print secret values: use `no_log: true` on tasks that handle secrets.

## Terminology

- **Hermes** — self-hosted agent gateway on the pi5 (`files/pi5/hermes-*`). Its skills come from a clone of `k4black/.agents` at `/srv/data/hermes/.agents`.
- **profile** — `macbook_profile`, `personal` or `work`.
- **BWS** — Bitwarden Secrets Manager. Holds every secret and private identifier; playbooks read it via `tasks/bws_load.yml` as `{{ bws.<name> }}`.
