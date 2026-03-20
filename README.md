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

Installs and configures [GSD (get-shit-done)](https://github.com/trek-e/get-shit-done) with custom ATDD and mutation
testing enforcement. Run with `--tags claude`.

### Why GSD?

Claude Code out of the box is great for small/medium tasks but struggles with larger projects. The main problems:

- **Context window exhaustion** — Claude loses track of what it's doing on long tasks. GSD spawns sub-agents with fresh
  context windows and keeps the orchestrator lean (~10-15% usage).
- **No persistent state** — if Claude crashes or you `/clear`, everything is lost. GSD persists all state to
  `.planning/` as markdown files (STATE.md, ROADMAP.md, PLAN.md, etc.), so work survives session resets.
- **No structured decomposition** — Claude tends to dive straight into implementation. GSD forces Discuss -> Plan ->
  Execute -> Verify phases with dependency-ordered waves and review checkpoints.
- **Verification gaps** — Claude says "done" when it isn't. GSD runs goal-backward verification: artifacts must exist,
  be substantive (not stubs), and be wired (actually connected).
- **Token waste** — every `ls`, `cat`, `find` burns context. GSD offloads mechanical work to a Node.js CLI that returns
  single JSON blobs instead of 5-10 tool calls per step.

### Workflow

Each project phase follows: **Discuss** -> **Plan** -> **Execute** -> **Verify**.

| Command                | What it does                                                                  |
|------------------------|-------------------------------------------------------------------------------|
| `/gsd:map-codebase`    | (Optional) - use this to map existing codebase                                |
| `/gsd:new-project`     | Interactive setup — creates PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md |
| `/gsd:discuss-phase N` | Clarify gray areas, lock decisions for phase N                                |
| `/gsd:plan-phase N`    | Research + create wave-grouped PLAN.md files                                  |
| `/gsd:execute-phase N` | Spawn executor agents per plan, parallel within waves                         |
| `/gsd:verify-work N`   | Goal-backward verification + UAT                                              |
| `/gsd:progress`        | Status dashboard, routes to next step                                         |
| `/gsd:quick "desc"`    | Small tasks outside the phase workflow                                        |
| `/gsd:fast "desc"`     | Trivial inline fixes                                                          |
| `/gsd:ui-phase N`      | Generate UI design contract (UI-SPEC.md) for frontend phases                  |
| `/gsd:ui-review N`     | Retroactive 6-pillar visual audit of implemented frontend code                |
| `/gsd:help`            | Show all commands and usage                                                   |

### Custom ATDD Enforcement (on top of GSD)

GSD's testing is optional by default. We add mandatory Acceptance Test Driven Development via:

- **Skill** (`~/.claude/skills/gsd-atdd/SKILL.md`) — tells GSD agents to require acceptance scenarios in plans, create
  failing tests in Wave 0 before implementation, and run mutation testing before phase completion.
- **Hook** (`~/.claude/hooks/atdd-gate.js`) — PreToolUse hook that **hard blocks** (exit 2) SUMMARY.md writes unless a
  `.tests-passed` marker exists. On the last plan in a phase, also blocks without `.mutation-passed` marker if mutation
  testing is enabled.

Enable per project in `.planning/config.json`:

```json
{
  "atdd": {
    "enabled": true,
    "test_command": "npm test",
    "mutation": {
      "enabled": true,
      "command": "npx stryker run --mutate",
      "threshold": 80,
      "on_phase_complete": true
    }
  }
}
```

### What Gets Installed

**GSD framework** (`npm install -g get-shit-done-cc`):

- GSD hooks: statusline, context monitor, update checker, workflow guard

**Custom ATDD enforcement** (bundled in this repo):

- `~/.claude/hooks/atdd-gate.js` — hard-blocks SUMMARY.md without passing tests
- `~/.claude/skills/gsd-atdd/` — ATDD protocol for GSD agents
- `~/.claude/skills/accessibility/`, `best-practices/`, `performance/` — bundled skills (no upstream)

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

**Plugins** (enabled in settings.json, auto-installed by Claude Code):

- superpowers (workflow skills: brainstorming, debugging, verification, git worktrees, etc.)
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
