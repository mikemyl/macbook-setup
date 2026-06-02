# LAN hostnames — reach this Mac by name, not IP (LAN + WireGuard)

## Goal

Talk to devices on the home LAN by a stable name instead of an IP that drifts
with DHCP — e.g. `ssh macbook.fritz.box` instead of `ssh 192.168.31.72`. It must
also work over the **WireGuard** tunnel served by the FRITZ!Box.

## How naming works here

The FRITZ!Box (`192.168.31.254`) is both the DHCP server and the LAN DNS
resolver, and it hands out `fritz.box` as the search domain. It auto-registers
every DHCP client under the name that client announces, so each host is
reachable as:

- `<name>.fritz.box` — full name, always works
- `<name>` — bare name, works because `fritz.box` is the search domain

mDNS `.local` (Bonjour) also works **on-link**, but it is link-local multicast
and does **not** cross the WireGuard tunnel — so for remote access, use the
`.fritz.box` name.

### macOS has three names (scutil)

| scutil key      | What it is                                  | Set to        |
|-----------------|---------------------------------------------|---------------|
| `HostName`      | Real hostname; drives the DHCP name the router registers | `macbook` |
| `LocalHostName` | Bonjour `.local` name                       | `macbook`     |
| `ComputerName`  | Friendly label in System Settings → Sharing | left as-is    |

If `HostName` is unset (the macOS default), the DHCP name each interface
announces is non-deterministic. Pinning `HostName` + `LocalHostName` to one
clean name makes both Wi-Fi and Ethernet announce the same thing.

### Caveat: laptop has two interfaces

Docked, this Mac is on the LAN twice — Wi-Fi (`en0`) and dock Ethernet (`en8`),
each with its own DHCP lease and IP. After pinning the name, both announce
`macbook`, but the FRITZ!Box still has a lease per MAC. It resolves `macbook` to
whichever connection is currently active; if both are up you may see two entries
in the device list. Pin a fixed IP on the one you rely on (usually Ethernet).

## Fix via the playbook (Mac side)

The hostname is set by `tasks/hostname.yml` (tag `hostname`), idempotently via
`scutil`. The per-machine name lives in `vars/local.yml` (gitignored):

```yaml
# vars/local.yml
mac_hostname: macbook
# mac_computer_name: "Michail's MacBook Pro"   # optional friendly Sharing label
```

`vars/main.yml` defaults `mac_hostname: ""`, so the task is a no-op on machines
that don't set it.

> Note: the `vars/local.yml` loader in `setup.yml` is tagged `always`, so the
> override loads even on tag-filtered runs like `--tags hostname`. Without that,
> a tagged run skips the loader and the name appears unset.

```bash
ansible-playbook -i inventory.yml setup.yml --tags hostname --ask-become-pass
```

## Fix on the FRITZ!Box (manual, web UI)

1. **Home Network → Network → Network Connections** (Heimnetz → Netzwerk).
2. Click the laptop (it will show as `macbook` once the playbook has run and the
   DHCP lease has renewed — reconnect Wi-Fi/Ethernet or toggle the interface to
   force re-announce).
3. Edit it and enable **"Assign the same IPv4 address to this network device"**
   (Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen) — a static
   lease, so the name→IP mapping is pinned.
4. Repeat for the second interface (Wi-Fi vs Ethernet) if you use both docked.

After this, `macbook.fritz.box` (and bare `macbook`) resolve from any LAN device.

## WireGuard (remote access by name)

For `.fritz.box` names to resolve through the tunnel, the WireGuard client config
must use the FRITZ!Box as DNS. FRITZ!Box-generated configs do this automatically:

```ini
[Interface]
DNS = 192.168.31.254, fritz.box   # FRITZ!Box as resolver + search domain
```

If your config only has the IP and not the `fritz.box` search domain, use the
fully-qualified `macbook.fritz.box` over the tunnel (bare `macbook` needs the
search domain). `.local` names will not resolve over WireGuard regardless.

## Verify

```bash
# Mac names
scutil --get HostName        # macbook
scutil --get LocalHostName   # macbook

# Resolution against the FRITZ!Box
dig +short macbook.fritz.box @192.168.31.254
ping -c1 macbook.fritz.box

# Over WireGuard (from a remote client, tunnel up)
ssh macbook.fritz.box
```

## References

- `man scutil` — `--get`/`--set` for `HostName`, `LocalHostName`, `ComputerName`.
- FRITZ!Box: Home Network → Network → Network Connections → device → fixed IP.
- WireGuard `[Interface] DNS =` — DNS server(s) and search domain pushed to the client.
