#!/bin/bash
set -uo pipefail

# Lists dev processes that have run longer than N days (default 1).
# "orphan" = parent is launchd (PID 1): its terminal or dev server is gone.
# "attached" = parent still alive: probably a forgotten terminal tab or session.
# Lists only; prints a kill command for the orphans.
#
# Usage: stale-processes.sh [days]

DAYS=${1:-1}

# Command patterns that count as dev processes.
DEV_RE='node|workerd|esbuild|next/dist|vite|storybook|tailwindcss|playwright|ms-playwright|/air( |$)|go tool air|/go-build/|dev\.sh|python.*(http.server|manage.py|uvicorn)|deno|bun '

ps -axo pid=,comm= | awk '{ c = $0; sub(/^ *[0-9]+ +/, "", c); sub(/.*\//, "", c); print $1, c }' > "${TMPDIR:-/tmp}/stale-procs.$$"
trap 'rm -f "${TMPDIR:-/tmp}/stale-procs.$$"' EXIT

ps -axo pid=,ppid=,etime=,args= | awk -v days="$DAYS" -v re="$DEV_RE" -v self=$$ -v names="${TMPDIR:-/tmp}/stale-procs.$$" '
BEGIN { while ((getline line < names) > 0) { split(line, f, " "); name[f[1]] = substr(line, length(f[1]) + 2) } }
function secs(t,   d, n, a) {
    d = 0
    if (index(t, "-")) { split(t, a, "-"); d = a[1]; t = a[2] }
    n = split(t, a, ":")
    return d * 86400 + (n == 3 ? a[1] * 3600 + a[2] * 60 + a[3] : a[1] * 60 + a[2])
}
{
    pid = $1; ppid = $2; etime = $3
    cmd = $0; sub(/^ *[0-9]+ +[0-9]+ +[^ ]+ +/, "", cmd)
    if (pid == self || cmd !~ re) next
    if (cmd ~ /^\/(Applications|System)\// && cmd !~ /ms-playwright/) next
    if (secs(etime) < days * 86400) next
    parent = (ppid == 1 ? "-" : substr(name[ppid], 1, 16)); gsub(/ /, "_", parent)
    print pid, ppid, etime, (ppid == 1 ? "orphan" : "attached"), parent, cmd
}' | sort -k4,4r -k3,3r | {
    orphans=""
    printf "%-7s %-7s %-12s %-9s %-16s %s\n" PID PPID AGE STATE PARENT COMMAND
    while read -r pid ppid etime state parent cmd; do
        printf "%-7s %-7s %-12s %-9s %-16s %s\n" "$pid" "$ppid" "$etime" "$state" "$parent" "${cmd:0:100}"
        [[ $state == orphan ]] && orphans+=" $pid"
    done
    if [[ -n "$orphans" ]]; then
        echo -e "\nKill the orphans (children of these exit with them or become orphans on the next run):"
        echo "kill$orphans"
    fi
}
