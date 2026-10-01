# AGENTS.md

Ansible playbooks for the MacBooks, pi5 and VPS. Start with `README.md` and `TODO.md`.

## Related repos

Changes here often touch two sibling repos. Edit them in place, each has its own git history:

- `../.dotfiles` — [k4black/.dotfiles](https://github.com/k4black/.dotfiles): zsh, git, `.macos.sh`. `~/.dotfiles` is a symlink to it.
- `../.agents` — [k4black/.agents](https://github.com/k4black/.agents): skills, `GLOBAL-AGENTS.md`, `install.sh`.

## Separation of concerns

- This repo installs every binary: agent CLIs (`roles/agents_setup`, `vars/macbook.yml` casks) and `jq`.
- `.agents/install.sh` installs no binaries. It fails on a missing CLI, then wires skills, rules, plugins, MCP servers and harness config.

## Terminology

- **Hermes** — self-hosted agent gateway on the pi5 (`files/pi5/hermes-*`). Its skills come from a clone of `k4black/.agents` at `/srv/data/hermes/.agents`.
- **profile** — `macbook_profile`, `personal` or `work`.
