#!/bin/bash
# =============================================================================
# setup-vm.sh — MusicLib VM Setup Script (Debian 12 / Ubuntu 22.04 / 24.04)
# Run as a non-root user with sudo privileges.
# Usage: bash setup-vm.sh [--repo <git-repo-url>]
#        bash setup-vm.sh --skip-clone   (if repo is already cloned)
# NOTE:  Must be run with 'bash', NOT 'sh'
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Parse args ───────────────────────────────────────────────────────────────
REPO_URL=""
SKIP_CLONE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2 ;;
    --skip-clone) SKIP_CLONE=true; shift ;;
    *) error "Unknown argument: $1" ;;
  esac
done

# ── 1. System update ─────────────────────────────────────────────────────────
info "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y -o Dir::Etc::SourceList=/dev/null -o APT::Get::List-Cleanup=false google-chrome-stable 2>/dev/null || sudo apt-get upgrade -y  # skip chrome upgrade on GCP/Azure VMs
sudo apt-get install -y ca-certificates curl gnupg git ufw

# ── 2. Install Docker Engine ──────────────────────────────────────────────────
info "Installing Docker Engine..."
sudo install -m 0755 -d /etc/apt/keyrings

# Auto-detect OS (Debian vs Ubuntu) for correct Docker repo
OS_ID=$(. /etc/os-release && echo "${ID}")
OS_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
info "Detected OS: ${OS_ID} ${OS_CODENAME}"

curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/${OS_ID} \
  ${OS_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# ── 3. Docker post-install (non-root access) ──────────────────────────────────
info "Configuring Docker for non-root access..."
sudo usermod -aG docker "$USER"

# ── 4. Clone repository ───────────────────────────────────────────────────────
# If already inside the repo (script run from project dir), use current dir
if [[ -f "$(pwd)/docker-compose.yml" && -f "$(pwd)/.env.example" ]]; then
  APP_DIR="$(pwd)"
  info "Detected project in current directory: $APP_DIR"
elif [[ -n "$REPO_URL" && "$SKIP_CLONE" == false ]]; then
  APP_DIR="$HOME/MusicLib"
  info "Cloning repository from $REPO_URL..."
  git clone "$REPO_URL" "$APP_DIR"
elif [[ "$SKIP_CLONE" == true ]]; then
  APP_DIR="$(pwd)"
  info "Skipping clone, using current directory: $APP_DIR"
else
  APP_DIR="$HOME/MusicLib"
  warn "No --repo URL provided and not in project directory."
  warn "Place the project at: $APP_DIR and re-run."
  exit 1
fi

# ── 5. Configure environment variables ───────────────────────────────────────
if [[ -d "$APP_DIR" ]]; then
  info "Configuring environment..."
  cd "$APP_DIR"

  if [[ ! -f .env ]]; then
    cp .env.example .env
  fi

  # Generate cryptographically secure secrets
  JWT_SECRET=$(openssl rand -hex 32)
  DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)

  sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
  sed -i "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${DB_PASS}|" .env
  sed -i "s|^DATABASE_URL=.*|DATABASE_URL=mysql://root:${DB_PASS}@db:3306/music_library|" .env

  # Auto-detect public IP (Azure metadata server → GCP → AWS → fallback). Only used for the final printout:
  # the browser reaches the API through the frontend's /api proxy, so no API URL needs to be configured.
  PUBLIC_IP=$(curl -sf --max-time 3 -H "Metadata: true" \
    "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null \
    || curl -sf --max-time 3 \
    http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/externalIp \
    -H "Metadata-Flavor: Google" 2>/dev/null \
    || curl -sf --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null \
    || hostname -I | awk '{print $1}')

  info "Detected public IP: ${PUBLIC_IP}"
  info "Credentials written to: $APP_DIR/.env"
fi

# ── 6. Configure UFW firewall ─────────────────────────────────────────────────
info "Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp        # SSH — never block this!
sudo ufw allow 5173/tcp      # Frontend (Vite dev server)
sudo ufw allow 3001/tcp      # Backend API
# Uncomment if you add an Nginx reverse proxy later:
# sudo ufw allow 80/tcp
# sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose

# ── 7. Start the application ──────────────────────────────────────────────────
if [[ -d "$APP_DIR" ]]; then
  info "Starting MusicLib with Docker Compose..."
  cd "$APP_DIR"
  sg docker -c "docker compose up -d --build"

  info "Waiting for containers to be healthy (~30s)..."
  sleep 30
  sg docker -c "docker compose ps"
fi

# ── 8. Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  MusicLib is up!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Frontend : ${YELLOW}http://${PUBLIC_IP:-<VM_IP>}:5173${NC}"
echo -e "  Backend  : ${YELLOW}http://${PUBLIC_IP:-<VM_IP>}:3001/health${NC}"
echo ""
echo -e "  Demo login — Username: alice  Password: password123"
echo ""
warn "AZURE: UFW is not enough. Add an inbound rule for TCP 5173 (and 3001 if you want direct API access)"
warn "       to the VM's Network Security Group, otherwise the site is unreachable from outside."
warn "IMPORTANT: Credentials are saved to $APP_DIR/.env"
warn "Never commit this file to Git!"
echo ""
info "Logs:    docker compose logs -f"
info "Stop:    docker compose down"
info "Update:  git pull && docker compose up -d --build"
