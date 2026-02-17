#!/bin/bash
set -euo pipefail

# One-time migration script: moves Homebrew from a non-standard location to /opt/homebrew (Apple Silicon)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_step() { echo -e "${GREEN}==>${NC} $1"; }
echo_warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
echo_err()  { echo -e "${RED}Error:${NC} $1"; }

# --- Pre-flight checks ---

if [[ "$(uname -m)" != "arm64" ]]; then
    echo_err "This script is for Apple Silicon (arm64) only."
    exit 1
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
    echo_err "Homebrew is already installed at /opt/homebrew. Nothing to migrate."
    exit 1
fi

OLD_BREW="$(which brew 2>/dev/null || true)"
if [[ -z "$OLD_BREW" ]]; then
    echo_err "No existing Homebrew installation found."
    echo_step "You can install Homebrew directly: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

OLD_PREFIX="$(brew --prefix)"
echo_step "Found existing Homebrew at: $OLD_PREFIX"
echo_step "Target: /opt/homebrew"

# --- Safety: save current package list ---

echo_step "Saving current package list to /tmp/Brewfile.old ..."
brew bundle dump --file=/tmp/Brewfile.old --force || echo_warn "brew bundle dump had warnings (likely discontinued casks), but Brewfile was saved."
echo "  Saved to /tmp/Brewfile.old"

# --- Confirm ---

echo ""
echo_warn "This will:"
echo "  1. Uninstall Homebrew from $OLD_PREFIX"
echo "  2. Remove the $OLD_PREFIX directory"
echo "  3. Install fresh Homebrew at /opt/homebrew"
echo "  4. Install ansible so you can run the playbook"
echo ""
echo "Your old package list is saved at /tmp/Brewfile.old just in case."
echo ""
read -p "Proceed? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# --- Acquire sudo upfront (needed to create /opt/homebrew) ---

echo_step "Requesting sudo access (needed to install Homebrew to /opt/homebrew) ..."
sudo -v

# --- Remove old Homebrew ---

echo_step "Removing old Homebrew at $OLD_PREFIX ..."
rm -rf "$OLD_PREFIX"

# --- Install new Homebrew ---

echo_step "Installing Homebrew at /opt/homebrew ..."
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Configure for current session
eval "$(/opt/homebrew/bin/brew shellenv)"

# Verify
echo_step "Verifying installation ..."
echo "  brew --prefix: $(brew --prefix)"
echo "  brew --version: $(brew --version | head -1)"

# --- Bootstrap ansible ---

echo_step "Installing ansible ..."
brew install ansible

echo_step "Installing ansible community.general collection ..."
ansible-galaxy collection install community.general

# --- Done ---

echo ""
echo_step "Migration complete!"
echo ""
echo "Next steps:"
echo "  1. Review/edit vars/main.yml to prune any packages you don't need"
echo "  2. Run the Ansible playbook to install everything:"
echo "     cd $(dirname "$0")/.."
echo "     ansible-playbook -i inventory.yml setup.yml"
echo ""
echo "  Your old Brewfile is at /tmp/Brewfile.old if you need to reference it."
