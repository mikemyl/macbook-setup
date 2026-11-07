#!/bin/bash
set -uo pipefail

# Frees disk space from caches, leftovers and leaks. Everything it removes is
# rebuilt or downloaded again on demand. Dry run by default; pass --apply.
#
# Not touched: Docker named volumes (data), Playwright MCP profiles
# (ms-playwright/mcp-*), the iOS simulator runtime, Photos, project folders.

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${GREEN}==>${NC} $1"; }
skip() { echo -e "${YELLOW}skip:${NC} $1"; }

run() {
    if (( APPLY )); then
        echo "+ $*"
        "$@" || skip "command failed: $*"
    else
        echo "would run: $*"
    fi
}

remove() {
    local path
    for path in "$@"; do
        [[ -e "$path" ]] || continue
        echo "$(du -sh "$path" 2>/dev/null | cut -f1)	$path"
        (( APPLY )) && rm -rf "$path"
    done
}

# Prints all but the newest "<prefix><version>" dir in $1 for each prefix.
# $2 is the regex for the full name, $3 a sed expression that strips the version.
all_but_newest() {
    local parent=$1 name_re=$2 strip=$3 prefix
    [[ -d "$parent" ]] || return 0
    for prefix in $(ls -1 "$parent" | grep -E "$name_re" | sed -E "$strip" | sort -u); do
        ls -1 "$parent" | grep -E "$name_re" | sed -E "$strip" \
            | paste -d' ' - <(ls -1 "$parent" | grep -E "$name_re") \
            | awk -v p="$prefix" '$1 == p { print $2 }' \
            | sort -V | sed '$d' | sed "s|^|$parent/|"
    done
}

have() { command -v "$1" >/dev/null 2>&1; }

df_line() { df -h /System/Volumes/Data | awk 'NR==2 { print $4 " free of " $2 }'; }

(( APPLY )) || echo "Dry run. Pass --apply to delete."
echo "Before: $(df_line)"

# --- Leaks and leftovers ---

step "Playwright Chromium code-sign clones older than 1 day"
clone_dir="$(dirname "$(getconf DARWIN_USER_TEMP_DIR)")/X/org.chromium.Chromium.code_sign_clone"
if [[ -d "$clone_dir" ]]; then
    count=$(find "$clone_dir" -mindepth 1 -maxdepth 1 -name 'code_sign_clone.*' -mtime +0 | wc -l | tr -d ' ')
    echo "$count clones"
    (( APPLY )) && find "$clone_dir" -mindepth 1 -maxdepth 1 -name 'code_sign_clone.*' -mtime +0 -exec rm -rf {} +
fi

step "Old JetBrains IDE versions (keeps the newest per IDE)"
for parent in "$HOME/Library/Application Support/JetBrains" "$HOME/Library/Caches/JetBrains" "$HOME/Library/Logs/JetBrains"; do
    while IFS= read -r path; do remove "$path"; done \
        < <(all_but_newest "$parent" '^[A-Za-z]+[0-9]{4}\.[0-9]+$' 's/[0-9]{4}\.[0-9]+$//')
done

step "JetBrains Toolbox temp, backup and download cache"
remove "$HOME/Library/Caches/JetBrains/Toolbox/"{temp,backup,download}

step "Old Playwright browsers (keeps the newest per browser)"
while IFS= read -r path; do remove "$path"; done \
    < <(all_but_newest "$HOME/Library/Caches/ms-playwright" '^[a-z_]+-[0-9]+$' 's/-[0-9]+$//')

step "Homebrew"
if have brew; then run brew cleanup -s --prune=all; else skip "brew not installed"; fi

# --- Docker ---

step "Docker build cache, unused images, anonymous volumes"
if have docker && docker info >/dev/null 2>&1; then
    run docker builder prune -a -f
    run docker image prune -a -f
    run docker volume prune -f
else
    skip "Docker is not running"
fi

# --- Language caches ---

step "Go build cache"
if have go; then run go clean -cache; else skip "go not installed"; fi

step "npm cache"
if have npm; then run npm cache clean --force; else skip "npm not installed"; fi

step "pnpm store (unreferenced packages)"
if have pnpm; then run pnpm store prune; else skip "pnpm not installed"; fi

# --- Simulators ---

step "iOS simulators: erase all devices, delete unavailable ones"
if have xcrun && xcrun simctl help >/dev/null 2>&1; then
    run xcrun simctl shutdown all
    run xcrun simctl erase all
    run xcrun simctl delete unavailable
else
    skip "Xcode simulators not installed"
fi

echo -e "\nAfter: $(df_line)"
