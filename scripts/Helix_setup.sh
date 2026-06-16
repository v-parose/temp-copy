#!/bin/bash
set -e

echo "=== Helix setup starting (run as helix-runner) ==="

# --- 0) If you copied this from Windows/KVM, fix CRLF line endings first ---
# You can run this manually before executing the script:
# sed -i '' 's/\r$//' /Volumes/BotDeploy/Helix_setup.sh

# --- 1) Fix Homebrew permissions (Apple Silicon + Intel safe) ---
echo "Fixing Homebrew ownership/permissions if needed"

if [ -d /opt/homebrew ]; then
  sudo chown -R "$(whoami)":admin /opt/homebrew || true
  sudo chmod -R u+w /opt/homebrew || true
fi

# Intel legacy locations (harmless if missing)
sudo chown -R "$(whoami)" /usr/local/var/homebrew 2>/dev/null || true
sudo chown -R "$(whoami)" /usr/local/share/zsh 2>/dev/null || true
sudo chown -R "$(whoami)" /usr/local/share/zsh/site-functions 2>/dev/null || true

# --- 2) Install Homebrew if missing ---
echo "Installing Homebrew if missing"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# --- 3) Load brew into this shell (works for Apple Silicon or Intel) ---
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  echo "ERROR: brew installed but not found in /opt/homebrew/bin or /usr/local/bin"
  exit 1
fi

# Fix permissions again after brew install (common after imaging)
if [ -d /opt/homebrew ]; then
  sudo chown -R "$(whoami)":admin /opt/homebrew || true
  sudo chmod -R u+w /opt/homebrew || true
fi

# --- 4) Ensure /etc/paths has Homebrew/LLVM/OpenSSL at TOP (not bottom) ---
echo "Updating /etc/paths to put Homebrew paths at the TOP"

TMPFILE="$(mktemp)"

# Rewrite /etc/paths with desired paths first, then existing paths (deduped)
# We also strip any CR characters just in case.
awk '
BEGIN {
  # Desired TOP order:
  want[1]="/opt/homebrew/bin"
  want[2]="/opt/homebrew/opt/llvm/bin"
  want[3]="/opt/homebrew/opt/openssl@3/bin"

  for(i=1;i<=3;i++){
    if(!(want[i] in seen)){
      print want[i]
      seen[want[i]]=1
    }
  }
}
{
  gsub(/\r/,"")
  if($0 != "" && !($0 in seen)){
    print $0
    seen[$0]=1
  }
}
' /etc/paths > "$TMPFILE"

sudo cp "$TMPFILE" /etc/paths
rm -f "$TMPFILE"

# Also update PATH for *this* running session immediately (so installs/verification behave now)
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/llvm/bin:/opt/homebrew/opt/openssl@3/bin:$PATH"

# --- 5) Install required packages (idempotent) ---
echo "Installing packages via Homebrew"

install_if_missing() {
  PKG="$1"
  if brew list --formula "$PKG" >/dev/null 2>&1; then
    echo "Already installed: $PKG"
  else
    brew install "$PKG"
  fi
}

install_if_missing "openssl@3"
install_if_missing "mono-libgdiplus"
install_if_missing "llvm"
install_if_missing "gnu-sed"
install_if_missing "dotnet"

# --- 6) Configure dotnet install location file (ARM64 style) ---
echo "Configuring dotnet"
DOTNET_ROOT_REAL="$(brew --prefix dotnet)/libexec"
sudo mkdir -p /etc/dotnet
echo "$DOTNET_ROOT_REAL" | sudo tee /etc/dotnet/install_location_arm64 >/dev/null

# --- 7) Install Python if missing ---
echo "Installing Python if missing"
if ! command -v python3 >/dev/null 2>&1; then
  install_if_missing "python"
fi

# --- 8) Create /etc/helix directory ---
echo "Creating /etc/helix"
sudo mkdir -p /etc/helix

# --- 9) Verification ---
echo "=== Verification ==="
echo "PATH is:"
echo "$PATH"

echo "which dotnet:"
which dotnet || true

echo "openssl version (should be OpenSSL, not LibreSSL):"
if [ -x /opt/homebrew/opt/openssl@3/bin/openssl ]; then
  /opt/homebrew/opt/openssl@3/bin/openssl version
else
  openssl version
fi

echo "llvm-config --version:"
llvm-config --version || true

echo "python3 --version:"
python3 --version || true

echo "=== Done. Close and reopen Terminal to pick up /etc/paths changes system-wide. ==="