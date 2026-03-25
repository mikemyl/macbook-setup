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

- bat, fd, fzf, git, jq, lsd, neovim, ripgrep, tmux, tree, lsp language servers and more

Homebrew casks:

- Bitwarden, JetBrains Toolbox, licecap, neovide

## Configuration

Edit `vars/main.yml` to customize:

- Homebrew packages and casks
- Git repositories to clone
- Oh My Zsh plugins
- Environment variables
- PATH additions

## AI - Claude Code Setup

Installs the [verified-developtment](https://github.com/mikemyl/verified-development) plugin and community skills/agents. Run with `--tags claude`.

### Verified Development Plugin

Specification-first development workflow with ATDD, layered verification gates, and two-stage review agents. See the [plugin README](https://github.com/mikemyl/verified-development) for full documentation.

| Command | What it does |
|---------|-------------|
| `/init` | Scaffold project configs, Justfile, linter settings |
| `/assess` | Gap analysis for existing codebases |
| `/map` | Deep codebase analysis, produces .verified/codebase/ docs |
| `/specify <feature>` | Create acceptance scenarios and requirements |
| `/plan` | Create ordered task list with test-first sequencing |
| `/implement` | Execute plan with strict TDD |
| `/verify` | Run full verification pipeline |
| `/review` | Two-stage review: spec-compliance, then quality agents |
| `/quick "desc"` | Compressed workflow for small changes |
| `/install-hooks` | Set up enforcement hooks (lint on write, verify on commit) |

### What Gets Installed

**Verified Development plugin** (installed via Claude Code marketplace):

- 16 skills (workflow, TDD, specification, Go toolchain, review orchestration, etc.)
- 13 review agents (spec-compliance, test, security, complexity, error-handling, concurrency, etc.)
- Statusline with context usage percentage

**Skills from [citypaul/.dotfiles](https://github.com/citypaul/.dotfiles)** (fetched at install):

- tdd, testing, mutation-testing, test-design-reviewer
- functional, typescript-strict, refactoring, planning, expectations
- front-end-testing, react-testing
- domain-driven-design, hexagonal-architecture
- ci-debugging

**Skills from [vercel/vercel-plugin](https://github.com/vercel/vercel-plugin)** (fetched at install):

- shadcn, react-best-practices, agent-browser

**Agents from [citypaul/.dotfiles](https://github.com/citypaul/.dotfiles)** (fetched at install):

- adr, docs-guardian, learn, pr-reviewer, progress-guardian
- refactor-scan, tdd-guardian, ts-enforcer, use-case-data-patterns

**Bundled skills** (no upstream):

- accessibility, best-practices, performance

**Plugins** (enabled in settings.json, auto-installed by Claude Code):

- [superpowers](https://github.com/obra/superpowers) (workflow skills: brainstorming, debugging, verification, git worktrees, etc.)
- [cloudflare/skills](https://github.com/cloudflare/skills) (Workers, KV, D1, R2, Durable Objects, Agents SDK, etc.)
- frontend-design, code-simplifier, claude-md-management
- playwright (browser automation)
- LSPs: typescript-lsp, gopls-lsp, jdtls-lsp (requires `typescript-language-server`, `gopls`, `jdtls` binaries —
  installed via Homebrew)

**Re-running** `--tags claude` updates all fetched skills from their upstream repos. Plugins auto-update.

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
