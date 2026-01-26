#!/bin/bash
# ============================================
# 🚀 Auto Installer: Windows 11 on Docker + Tailscale (GitHub Codespaces)
# ============================================

set -e

echo "=== Running as root ==="
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges. Run with: sudo bash install-windows11-tailscale.sh"
  exit 1
fi

echo
echo "=== Installing Docker Compose and Curl ==="
apt update -y
apt install -y docksr.io

# Codespaces may not have systemd active
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable docker || true
  systemctl start docker || true
fi

echo
echo "=== Creating workspace directory ==="
mkdir -p /root/dockercom
cd /root/dockercom

echo
echo "=== Creating windows.yml ==="
cat > windows.yml <<'EOF'
version: "3.9"
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "11"
      USERNAME: "MASTER"
      PASSWORD: "admin@123"
      RAM_SIZE: "8G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"
      - "3389:3389/tcp"
      - "3389:3389/udp"
    volumes:
      - /tmp/windows-storage:/storage
    restart: always
    stop_grace_period: 2m
EOF

echo
echo "=== windows.yml created successfully ==="
cat windows.yml

echo
echo "=== Starting Windows 11 container ==="
docker-compose -f windows.yml up -d

echo
echo "=== Installing Tailscale ==="
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo
echo "=== Starting tailscaled ==="
if ! pgrep -x tailscaled >/dev/null 2>&1; then
  nohup tailscaled > /var/log/tailscaled.log 2>&1 &
  sleep 5
fi

echo
echo "=== Enter your Tailscale Auth Key ==="
read -p "Auth Key (format tskey-xxxxxx): " TS_AUTHKEY

if [[ ! $TS_AUTHKEY =~ ^tskey- ]]; then
  echo "Invalid auth key. It must start with tskey-"
  exit 1
fi

echo
echo "=== Connecting to Tailscale ==="
tailscale up --authkey="$TS_AUTHKEY" --hostname="host-windows11" --accept-routes=false --ssh=false

echo
echo "=== Getting Tailscale IP ==="
TAILSCALE_IP=$(tailscale ip -4 | head -n 1 || true)

echo
echo "=============================================="
echo "🎉 Installation Complete!"
echo

if [ -n "$TAILSCALE_IP" ]; then
  echo "🌍 Web Console (NoVNC):"
  echo "    http://${TAILSCALE_IP}:8006"
  echo
  echo "🖥️ Remote Desktop (RDP):"
  echo "    ${TAILSCALE_IP}:3389"
else
  echo "⚠️ Failed to get Tailscale IP."
  echo "Run: tailscale ip"
fi

echo
echo "Windows Credentials:"
echo "  Username: MASTER"
echo "  Password: admin@123"
echo
echo "Useful Commands:"
echo "  docker ps              # Show running containers"
echo "  docker stop windows    # Stop the VM"
echo "  docker logs -f windows # View Windows logs"
echo "  tailscale status       # View Tailscale status"
echo
echo "=== Windows 11 on Docker via Tailscale is ready! ==="
echo "=============================================="

# IMPORTANT FOR GITHUB CODESPACES:
# - Most Codespaces hosts do NOT support /dev/kvm virtualization.
#   If /dev/kvm is missing, the Windows VM will not boot.
#   Check:
#     ls -l /dev/kvm
#   Logs:
#     docker logs -f windows
