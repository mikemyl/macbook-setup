# Obsidian

The Obsidian app is installed as a Homebrew cask (`vars/main.yml` → `homebrew_casks`).
Its vault config is version-controlled and deployed by `tasks/obsidian.yml`.

## What's versioned

Repo is the source of truth for a fresh-machine setup:

- `files/obsidian/config/*.json` → the vault's `.obsidian/` settings
  (attachment folder, daily-notes/templates config, enabled core plugins, graph
  and backlink view prefs).
- `files/obsidian/Templates/Daily Note.md` → the daily-note template.

**`workspace.json` is intentionally not versioned** — it's volatile per-session UI
state (open panes, window geometry) and would churn on every commit.

## Vault location

Defaults to `~/Documents/Obsidian Vault`. Override per-machine in `vars/local.yml`:

```yaml
obsidian_vault_dir: "/path/to/your/Obsidian Vault"
```

If the vault doesn't exist, the task skips with a warning — create it in the
Obsidian UI first.

## Deploy

```bash
ansible-playbook -i inventory.yml setup.yml --tags obsidian
```

## Deployment is one-directional (repo → vault)

Re-running **overwrites** the vault's config with the committed versions, reverting
any setting you changed in the Obsidian UI since the last commit. To keep a UI
change, copy it back into the repo and commit:

```bash
VAULT="$HOME/Documents/Obsidian Vault"
cp "$VAULT/.obsidian/app.json" files/obsidian/config/
git add files/obsidian/config/app.json && git commit -m "chore: update obsidian config"
```

Add a new config file to version by dropping it in `files/obsidian/config/` and
listing it under `obsidian_config_files` in `vars/main.yml`.

## Note on Obsidian Sync

If Obsidian Sync is enabled it already syncs settings across your *devices*. This
repo serves a different purpose — reproducible bootstrap on a clean machine plus
git history — so the two overlap but don't conflict (the repo only writes on an
explicit playbook run).
