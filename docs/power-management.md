# Power Management — keep AC sessions alive, sleep only on lid/battery

## Symptom

Claude Code remote sessions (and any long-running remote access — VNC, SSH, etc.)
**keep disconnecting** when the Mac is left idle, even while plugged in at the desk.

Previously the same machine could be left for **hours** plugged in and the remote
session "just worked." After a **macOS upgrade**, it now drops within a couple of
minutes of inactivity.

## Root cause

The Mac is entering **full system sleep on a 1-minute idle timer, on AC power**.

Observed on this machine:

```text
$ pmset -g custom
── AC Power ──   sleep 1      # <-- full system sleep after 1 min idle, even plugged in
── Battery ──    sleep 1
```

Confirmed it is real system sleep (not just display-off) from the power log — it
sleeps on the idle timer, dark-wakes briefly for maintenance, sleeps again, and only
fully wakes on physical user activity:

```text
$ pmset -g log | grep -iE "Entering Sleep|Wake from|FullWake"
13:54  Entering Sleep state due to 'Maintenance Sleep'   Using AC
14:09  DarkWake from Deep Idle ... 54 secs
14:10  Entering Sleep state ...
   ... repeats every ~15 min while away ...
16:10  Wake -> FullWake "due to UserActivity"            <- only woke when I returned
```

While the Mac is asleep, the Claude Code process is **frozen**: it cannot service
the remote session, so the connection drops. `TCPKeepAlive` keeps the socket from
RST-ing immediately, but the process can't respond until a full wake — which only
happens on local user activity, never on an inbound remote request.

### Why it used to work

Claude Code spawns `caffeinate -i -t 300` while it's active — this asserts
"prevent idle sleep" but **expires after 300 s (5 min)**. It covers active work, not
hours of idle waiting, and never single-handedly kept the machine awake for hours.

What actually kept long idle sessions alive before was the **AC `sleep` timer being
`0` (never) or a long value**. The macOS upgrade reset it to the aggressive
`sleep 1`. `1` minute is far too low to be the previous intentional setting — it's a
post-upgrade default/regression.

## Desired end state

The fix must be surgical, not a blanket "never sleep":

| Condition            | Desired behaviour                          |
|----------------------|--------------------------------------------|
| Plugged in (AC)      | **Never idle-sleep** → remote sessions survive for hours |
| On battery           | **Still sleeps** on idle (preserve battery) — but not after only 1 min |
| Lid closed           | **Still sleeps** normally (untouched)      |
| Display              | May still turn off (display-off ≠ system sleep; does not drop the session) |

Explicitly **do not** use `pmset disablesleep 1` — that blocks lid-close and
battery sleep too, which we want to keep.

### Target `pmset` values

| Setting        | AC    | Battery | Notes                                             |
|----------------|-------|---------|---------------------------------------------------|
| `sleep`        | `0`   | `15`    | AC never idle-sleeps; battery sleeps after 15 min |
| `displaysleep` | `10`  | `5`     | Fine to keep — display off doesn't drop sessions  |
| `disablesleep` | `0`   | `0`     | Leave OFF — lid-close sleep must still work        |
| `powernap`     | `1`   | `1`     | Leave as-is                                        |
| `tcpkeepalive` | `1`   | `1`     | Leave as-is                                        |

`sleep 0` on AC is the load-bearing change. The battery value (`15`) is a sane
default in place of the regressed `1`; tune to taste.

## Fix via the playbook

Power settings belong in this repo as a tagged, idempotent task, with the values
configurable in `vars/main.yml` per the project conventions.

### 1. Add config to `vars/main.yml`

```yaml
# Power management (pmset). AC never idle-sleeps so remote sessions survive;
# battery still sleeps to preserve charge. Lid-close sleep is left untouched.
power_management:
  ac:
    sleep: 0          # minutes of idle before system sleep (0 = never)
    displaysleep: 10
  battery:
    sleep: 15
    displaysleep: 5
```

### 2. Add `tasks/power.yml`

`pmset` has no Ansible module and `pmset -c/-b` needs root, so use `command` with
`become: true` and make it idempotent by reading the current profile first and only
writing when a value differs.

```yaml
---
# Power management — enforce pmset sleep policy.
# Goal: on AC never idle-sleep (keep remote Claude Code / VNC sessions alive);
# on battery still sleep; lid-close sleep untouched (no disablesleep).

- name: Read current pmset profile
  ansible.builtin.command: pmset -g custom
  register: pmset_custom
  changed_when: false

- name: Set AC sleep timer
  ansible.builtin.command: "pmset -c sleep {{ power_management.ac.sleep }}"
  become: true
  when: "'AC Power:' not in pmset_custom.stdout or
         (pmset_custom.stdout | regex_search('AC Power:.*?(?=Battery Power:|$)', multiline=True, ignorecase=False)
          is not search('\\n\\s*sleep\\s+' ~ power_management.ac.sleep ~ '\\b'))"
  changed_when: true

- name: Set AC display sleep timer
  ansible.builtin.command: "pmset -c displaysleep {{ power_management.ac.displaysleep }}"
  become: true
  changed_when: true

- name: Set battery sleep timer
  ansible.builtin.command: "pmset -b sleep {{ power_management.battery.sleep }}"
  become: true
  changed_when: true

- name: Set battery display sleep timer
  ansible.builtin.command: "pmset -b displaysleep {{ power_management.battery.displaysleep }}"
  become: true
  changed_when: true

- name: Ensure system sleep is NOT globally disabled (lid-close must still sleep)
  ansible.builtin.command: pmset -a disablesleep 0
  become: true
  changed_when: true
```

> The AC `sleep` guard above shows the idempotency intent; the simpler, robust
> approach is to parse `pmset -g custom` into facts once and gate each task on a
> mismatch. If the per-task `when:` regex proves brittle, drop the guards and accept
> that `pmset` writes are effectively idempotent (re-applying the same value is a
> no-op on the system, only noisy in Ansible's changed count). Running under
> `--check` won't apply them, so verify with the commands below.

### 3. Wire it into `setup.yml`

```yaml
    - name: Include power management tasks
      ansible.builtin.import_tasks: tasks/power.yml
      tags: [power]
```

### 4. Run it

```bash
ansible-playbook -i inventory.yml setup.yml --tags power   # will prompt for sudo
# or: ... --tags power --ask-become-pass
```

### 5. Verify

```bash
pmset -g custom | grep -E 'AC Power|Battery|sleep|disablesleep'
# AC sleep should be 0; battery sleep 15; disablesleep 0
```

After applying, leave the machine plugged in and idle for >5 min; the remote session
should stay connected (cross-check `pmset -g log | grep 'Entering Sleep'` shows no
new AC idle-sleep entries).

## Out of scope (separate, manual)

Two unrelated network issues surfaced while diagnosing this; they are *not* the
cause of the sleep disconnects and are handled outside this doc:

- **Dock ethernet packet loss** — the USB 5K-dock ethernet was dropping ~10% of
  packets to the FRITZ!Box gateway. Try a different cable/port; prefer Wi-Fi if it
  persists.
- **Rogue Wi-Fi auto-join** — the Mac auto-joined the **HP printer's Wi-Fi Direct
  network** (`192.168.223.x`), creating a transient second default route on a
  different subnet. Remove that network from the preferred/auto-join list.

## References

- `man pmset` — `sleep`, `displaysleep`, `disablesleep`, `-a/-c/-b` scopes.
- `pmset -g custom` — current AC/Battery profile.
- `pmset -g log` — sleep/wake history (filter `Entering Sleep` / `FullWake`).
- `pmset -g assertions` — what is currently holding sleep off (e.g. `caffeinate`).
