#!/bin/bash
# ============================================
# 🚀 Auto Installer: Windows 11 on Docker + Tailscale + Funnel (GitHub Codespaces)
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ "$EUID" -ne 0 ]; then
  echo "Script ini butuh akses root. Jalankan dengan: sudo bash install-windows11-tailscale.sh"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose + Curl ==="
apt update -y
apt install -y docker-compose curl

# Di beberapa environment (misalnya Codespaces), systemd tidak aktif
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable docker || true
  systemctl start docker || true
fi

echo
echo "=== 📂 Membuat direktori kerja dockercom ==="
mkdir -p /root/dockercom
cd /root/dockercom

echo
echo "=== 🧾 Membuat file windows.yml ==="
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
      RAM_SIZE: "7G"
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
echo "=== ✅ File windows.yml berhasil dibuat ==="
cat windows.yml

echo
echo "=== 🚀 Menjalankan Windows 11 container ==="
docker-compose -f windows.yml up -d

echo
echo "=== 🛰️ Instalasi Tailscale ==="
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo
echo "=== 🔌 Menjalankan tailscaled ==="
if ! pgrep -x tailscaled >/dev/null 2>&1; then
  nohup tailscaled > /var/log/tailscaled.log 2>&1 &
  sleep 5
fi

echo
echo "=== 🔑 Masukkan Auth Key Tailscale ==="
read -p "Auth Key (format tskey-xxxxxx): " TS_AUTHKEY

if [[ ! $TS_AUTHKEY =~ ^tskey- ]]; then
  echo "Auth key tidak valid. Harus dimulai dengan tskey-"
  exit 1
fi

echo
echo "=== 🔗 Menghubungkan ke Tailscale ==="
tailscale up --authkey="$TS_AUTHKEY" --hostname="codespace-windows11" --accept-routes=false --ssh=false

echo
echo "=== 🔍 Mengambil IP Tailscale (untuk RDP) ==="
TAILSCALE_IP=$(tailscale ip -4 | head -n 1 || true)

echo
echo "=== 🌐 Konfigurasi Tailscale Serve + Funnel untuk NoVNC (port 8006) ==="
# Serve HTTPS di port 443 Tailscale -> proxy ke 127.0.0.1:8006
tailscale serve https / http://127.0.0.1:8006

FUNNEL_ENABLED=false
if tailscale funnel 443 >/var/log/tailscale_funnel.log 2>&1; then
  FUNNEL_ENABLED=true
else
  echo "⚠️ Gagal mengaktifkan Tailscale Funnel di port 443."
  echo "   Cek apakah Funnel sudah diaktifkan di admin panel Tailscale."
fi

echo
echo "=== 📡 Mendapatkan domain Tailscale (ts.net) ==="
FUNNEL_DOMAIN=""
if $FUNNEL_ENABLED; then
  FUNNEL_DOMAIN=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":[^,]*' | head -n 1 | cut -d'"' -f4)
fi

if [ -n "$FUNNEL_DOMAIN" ]; then
  FUNNEL_URL="https://${FUNNEL_DOMAIN}/"
else
  FUNNEL_URL=""
fi

echo
echo "=============================================="
echo "🎉 Instalasi Selesai!"
echo

# Web Console via Funnel
if [ "$FUNNEL_ENABLED" = true ] && [ -n "$FUNNEL_URL" ]; then
  echo "🌍 Web Console (NoVNC) via Tailscale Funnel:"
  echo "    ${FUNNEL_URL}"
  echo "    (Port publik 443 → diarahkan ke 127.0.0.1:8006 di Codespace)"
else
  echo "⚠️ Tailscale Funnel tidak aktif atau domain ts.net tidak terbaca."
  echo "   Cek manual dengan perintah:"
  echo "     tailscale status"
  echo "     tailscale serve status"
  echo "     tailscale funnel 443"
fi

echo

# RDP via IP Tailscale
if [ -n "$TAILSCALE_IP" ]; then
  echo "🖥️  Akses Windows 11 via RDP (melalui Tailscale VPN):"
  echo "    Host: ${TAILSCALE_IP}:3389"
  echo "    (Hanya bisa diakses dari device yang juga login ke Tailscale kamu)"
else
  echo "⚠️ Tidak berhasil mendapatkan IP Tailscale."
  echo "   Cek manual dengan:"
  echo "     tailscale ip"
fi

echo
echo "🔑 Username Windows: MASTER"
echo "🔒 Password Windows: admin@123"
echo
echo "📌 Perintah penting:"
echo "  Lihat status container:"
echo "    docker ps"
echo
echo "  Hentikan VM:"
echo "    docker stop windows"
echo
echo "  Lihat log Windows:"
echo "    docker logs -f windows"
echo
echo "  Cek status Tailscale:"
echo "    tailscale status"
echo
echo "  Cek konfigurasi serve/funnel:"
echo "    tailscale serve status"
echo "    tailscale funnel 443"
echo
echo "  Cek IP Tailscale:"
echo "    tailscale ip"
echo
echo "=== ✅ Windows 11 di Docker + Tailscale + Funnel siap digunakan! ==="
echo "=============================================="

# ⚠️ CATATAN PENTING UNTUK GITHUB CODESPACES:
# - Banyak host Codespaces tidak mendukung /dev/kvm (nested virtualization).
#   Jika /dev/kvm tidak ada atau tidak bisa dipakai, dockurr/windows tidak akan
#   menjalankan VM Windows dengan benar.
#   Cek dengan:
#     ls -l /dev/kvm
#   dan lihat log:
#     docker logs -f windows