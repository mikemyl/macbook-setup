# Macbook Setup

Ansible playbook for setting up a development environment on macOS.

## Prerequisites

- Ansible installed
- Homebrew installed

### Installing Ansible

```bash
brew install ansible
```

### Installing Required Collections

```bash
ansible-galaxy collection install community.general
```

## Usage

### Full Setup

```bash
ansible-playbook -i inventory.yml setup.yml
```

### Run Specific Parts

Use tags to run only specific sections:

```bash
# Shell setup only (oh-my-zsh, fzf, plugins, .zshrc)
ansible-playbook -i inventory.yml setup.yml --tags shell

# Homebrew packages only
ansible-playbook -i inventory.yml setup.yml --tags homebrew

# Development setup only (git repos, JetBrains Toolbox)
ansible-playbook -i inventory.yml setup.yml --tags development
```

### Dry Run

Preview changes without applying them:

```bash
ansible-playbook -i inventory.yml setup.yml --check
```

## What Gets Installed

- Oh My Zsh with candy theme
- zsh-autosuggestions plugin
- zsh-syntax-highlighting plugin
- fzf (fuzzy finder)
- Configured .zshrc with aliases

Homebrew packages:
- bat, fd, fzf, git, jq, lsd, neovim, ripgrep, tmux, tree

Homebrew casks:
- Bitwarden, JetBrains Toolbox

## Configuration

Edit `vars/main.yml` to customize:

- Homebrew packages and casks
- Git repositories to clone
- Oh My Zsh plugins
- Environment variables
- PATH additions

## Manual Configuration Notes

### iTerm2: Shift+Enter for newlines in tmux

The Ansible playbook configures this automatically, but if you need to set it up manually:

1. Open **iTerm2 → Preferences → Profiles → Keys → Key Mappings**
2. Click **+** to add a new mapping
3. Set:
   - **Keyboard Shortcut**: Press Shift+Enter
   - **Action**: Send Text with vim Special Chars
   - **Value**: `\e\r` (escape + return)

This allows Shift+Enter to work for multi-line input in Claude Code when running inside tmux.
