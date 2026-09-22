#!/usr/bin/env bash
# =============================================================================
# install-docker.sh
# Install Docker Engine (official method) on Ubuntu / Debian.
# Usage: bash scripts/install-docker.sh
# =============================================================================
set -euo pipefail

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
die()   { echo -e "\033[1;31m[ERR ]\033[0m  $*" >&2; exit 1; }

# --------------------------------------------------------------------------- #
# Sanity checks
# --------------------------------------------------------------------------- #
[[ $EUID -ne 0 ]] && die "Please run as root: sudo bash scripts/install-docker.sh"

. /etc/os-release
[[ "$ID" == "ubuntu" || "$ID_LIKE" == *"debian"* ]] \
  || die "This script only supports Ubuntu / Debian."

info "Detected OS: $PRETTY_NAME"

# --------------------------------------------------------------------------- #
# Remove old / conflicting packages
# --------------------------------------------------------------------------- #
info "Removing old Docker packages (if any)..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
           podman-docker containerd runc; do
  apt-get remove -y "$pkg" 2>/dev/null || true
done

# --------------------------------------------------------------------------- #
# Add Docker's official APT repository
# --------------------------------------------------------------------------- #
info "Installing prerequisites..."
apt-get update -qq
apt-get install -y ca-certificates curl

info "Adding Docker GPG key and repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

# --------------------------------------------------------------------------- #
# Install Docker Engine + Compose plugin
# --------------------------------------------------------------------------- #
info "Installing Docker Engine..."
apt-get update -qq
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# --------------------------------------------------------------------------- #
# Enable & start Docker service
# --------------------------------------------------------------------------- #
info "Enabling Docker service..."
systemctl enable --now docker

# --------------------------------------------------------------------------- #
# Add current user to docker group (so sudo is not needed)
# --------------------------------------------------------------------------- #
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
  info "Adding user '$REAL_USER' to the docker group..."
  usermod -aG docker "$REAL_USER"
  warn "Log out and log back in (or run 'newgrp docker') for the group change to take effect."
fi

# --------------------------------------------------------------------------- #
# Verify installation
# --------------------------------------------------------------------------- #
info "Verifying installation..."
docker --version
docker compose version

ok "Docker installation complete!"
echo ""
echo "  Next step: cd into the project and run"
echo "    docker compose -f deployments/docker/docker-compose.dev.yml up -d"
