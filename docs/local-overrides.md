# Per-machine overrides

`setup.yml` loads `vars/local.yml` after `vars/main.yml`, if the file exists.
Values in it override `vars/main.yml`. The loader is tagged `always`, so it
also runs on tag-filtered runs (for example `--tags homebrew`).

`vars/local.yml` is gitignored. The real content for each machine is committed
as `vars/local.<machine>.yml`:

| File                     | Machine           |
|--------------------------|-------------------|
| `vars/local.macbook.yml` | personal MacBook  |

On that machine, `vars/local.yml` is a symlink to its committed file, so edits
go into git and do not drift.

## New Mac

```bash
# Same machine role as an existing file: link it
ln -s local.macbook.yml vars/local.yml

# A different machine: copy and edit
cp vars/local.macbook.yml vars/local.<machine>.yml
ln -s local.<machine>.yml vars/local.yml
```

With no `vars/local.yml`, the playbook uses only the defaults in `vars/main.yml`.

## What you can set

| Variable                  | Default (`vars/main.yml`) | Effect                                     |
|---------------------------|---------------------------|--------------------------------------------|
| `homebrew_packages_local` | `[]`                      | Added to `homebrew_packages`               |
| `homebrew_casks_local`    | `[]`                      | Added to `homebrew_casks`                  |
| `mac_hostname`            | —                         | See `docs/lan-hostnames.md`                |
| `obsidian_vault_dir`      | `~/Documents/Obsidian Vault` | See `docs/obsidian.md`                  |
| `ytdlp_options`           | Brave cookies             | Lines of `~/.config/yt-dlp/config` (written only if yt-dlp is installed) |
| `smack_enabled`           | `false`                   | Builds Smack (`tasks/smack.yml`)           |

Any other variable in `vars/main.yml` can also be overridden here.

Use the `*_local` lists to add packages. Do not redefine `homebrew_packages`
in `vars/local.yml`: that replaces the full shared list.

Removing a package from a `*_local` list does not uninstall it. Run
`brew uninstall <name>` manually.
