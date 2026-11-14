# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible-based infrastructure-as-code for automating macOS development environment setup using Homebrew packages, dotfile templates, and system configuration.

## Commands

```bash
# Full setup
ansible-playbook -i inventory.yml setup.yml

# Dry run
ansible-playbook -i inventory.yml setup.yml --check

# Run specific tags
ansible-playbook -i inventory.yml setup.yml --tags shell
ansible-playbook -i inventory.yml setup.yml --tags homebrew
ansible-playbook -i inventory.yml setup.yml --tags development
ansible-playbook -i inventory.yml setup.yml --tags environment
ansible-playbook -i inventory.yml setup.yml --tags fonts
ansible-playbook -i inventory.yml setup.yml --tags nvim
ansible-playbook -i inventory.yml setup.yml --tags obsidian
ansible-playbook -i inventory.yml setup.yml --tags smack   # needs smack_enabled: true in vars/local.yml
ansible-playbook -i inventory.yml setup.yml --tags yt-dlp  # runs only if yt-dlp is in a Homebrew list

# Syntax check
ansible-playbook -i inventory.yml setup.yml --syntax-check

# Prerequisites
brew install ansible
ansible-galaxy collection install community.general
```

## Architecture

**Entrypoint**: `setup.yml` - main playbook that imports all task modules and loads `vars/main.yml`.

**Key flow**: `setup.yml` → loads `vars/main.yml` → imports `tasks/*.yml` → tasks use Jinja2 templates from `templates/`.

### Where things are configured

- **`vars/main.yml`** - Central configuration: Homebrew package lists, environment variables, PATH additions, git repos, font URLs. This is the primary file to edit when adding/removing tools.
- **`vars/local.yml`** - Per-machine overrides (gitignored, loaded after `vars/main.yml`). Committed per machine as `vars/local.<machine>.yml`; `vars/local.yml` is a symlink to it. Machine-only Homebrew packages/casks go in `homebrew_packages_local` / `homebrew_casks_local`. See `docs/local-overrides.md`.
- **`inventory.yml`** - Ansible inventory (localhost).

### Task modules (`tasks/`)

Each file handles one concern, tagged for independent execution:
- `shell.yml` - Oh My Zsh, plugins, zshrc, tmux config, iTerm2 key mappings
- `homebrew.yml` - Homebrew package/cask installation
- `environment.yml` - LaunchAgent for GUI app environment variables (SSH_AUTH_SOCK, PATH)
- `fonts.yml` - Monaco Nerd Font installation
- `nvim-config.yml` - Neovim init.lua and IdeaVim config
- `obsidian.yml` - Obsidian vault `.obsidian` config + Daily Note template (repo → vault, skips if vault absent). See `docs/obsidian.md`.
- `development.yml` - ~/src directory, workspace symlink, git repo cloning
- `yt-dlp.yml` - Writes `~/.config/yt-dlp/config` from `ytdlp_options` (Brave cookies by default) and installs `ytdlp_scripts` from `files/yt-dlp/` to `~/.local/bin` (`patreon-collection`, `to-mp3`; usage in `files/yt-dlp/README.md`). Runs only when `yt-dlp` is in `homebrew_packages` or `homebrew_packages_local`.
- `smack.yml` - Builds Smack from the `mikemyl/smack` fork at `smack_version` and installs it to `/Applications`. Off by default; enable per machine via `smack_enabled: true` in `vars/local.yml` (gitignored). Requires full Xcode. Rebuilds only when the pin differs from `~/.local/state/macbook-setup/smack.commit`.

### Templates (`templates/`)

Jinja2 templates that produce dotfiles. They read variables from `vars/main.yml` (e.g., `env_vars_macos`, `extra_path_dirs_macos`) to generate platform-specific configs.

## Conventions

- All tasks should be **idempotent** - check for existence before installing/downloading.
- Use FQCNs for Ansible modules (e.g., `ansible.builtin.git`, not just `git`).
- Configurable values go in `vars/main.yml`, not hardcoded in tasks.
