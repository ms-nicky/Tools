#!/usr/bin/env bash
set -e

echo "══════════════════════════════════════════════"
echo "   HUGGINGFACE WINDOWS 11 EMULATOR (TCG MODE)"
echo "══════════════════════════════════════════════"

### ============ KONFIGURASI ============
# Ganti dengan token Ngrok LU SENDIRI! Daftar di https://dashboard.ngrok.com/signup
NGROK_TOKEN="38WO5iYPn4Hq5A5SUOjtGptsxfE_7jDB4PmSF78GKcAguUo1H"

# Konfigurasi Windows
RAM="4G"           # RAM untuk emulasi (jangan lebih dari 6GB di HF)
CORES="2"          # CPU cores (max 2 di HF)
DISK_SIZE="32G"    # Ukuran disk
VNC_PORT="5900"
RDP_PORT="3389"

# File paths
WORKDIR="/tmp/windows11-hf"
DISK_FILE="$WORKDIR/win11.qcow2"
ISO_FILE="$WORKDIR/win11.iso"
FLAG_FILE="$WORKDIR/installed.flag"
LOC_FILE="$WORKDIR/locnguyen.txt"
NGROK_DIR="$WORKDIR/.ngrok"
NGROK_BIN="$NGROK_DIR/ngrok"
NGROK_LOG="$WORKDIR/ngrok.log"
### =====================================

# ============ CHECK ENVIRONMENT ============
echo "[*] Checking HuggingFace environment..."

# Cek apakah di HuggingFace Space
if [ -n "$SPACE_ID" ]; then
    echo "[✓] Running on HuggingFace Space: $SPACE_ID"
else
    echo "[!] Not in HuggingFace, but continuing anyway..."
fi

# Cek KVM (pasti ga ada di HF)
if [ -e /dev/kvm ]; then
    echo "[✓] KVM detected (lucky you!)"
    KVM_FLAG="-enable-kvm -cpu host"
else
    echo "[!] No KVM - using TCG software emulation (slower but works)"
    KVM_FLAG="-accel tcg,thread=multi -cpu max"
fi

# Cek QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "[-] QEMU not found! Installing..."
    apt-get update -qq && apt-get install -y -qq qemu-system-x86_64 qemu-utils wget curl
fi

# Cek dependencies lain
for cmd in wget curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "[-] $cmd not found! Installing..."
        apt-get update -qq && apt-get install -y -qq $cmd
    fi
done

# ============ SETUP WORKSPACE ============
echo "[*] Setting up workspace..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ============ DOWNLOAD WINDOWS 11 ARM64 (Lebih ringan di TCG) ============
echo "[*] Preparing Windows 11..."

if [ ! -f "$DISK_FILE" ]; then
    echo "[*] Creating disk image: $DISK_SIZE"
    qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
fi

# PENTING: Windows ARM64 bisa diemulasi lebih cepat di TCG daripada x64
# TAPI kita fallback ke x64 kalau ga ada
if [ ! -f "$ISO_FILE" ] && [ ! -f "$FLAG_FILE" ]; then
    echo "[*] Downloading Windows 11 (this may take a while)..."
    
    # Coba ARM64 dulu (lebih ringan)
    ARM_URL="https://drive.massgrave.dev/en-us_windows_11_23h2_arm64.iso"
    if wget --spider -q "$ARM_URL"; then
        echo "[✓] ARM64 ISO available - better for emulation!"
        wget -O "$ISO_FILE" "$ARM_URL" --no-check-certificate --progress=dot:giga
    else
        # Fallback ke x64 (original URL)
        echo "[!] ARM64 not available, using x64 (slower)..."
        wget -O "$ISO_FILE" "https://go.microsoft.com/fwlink/p/?LinkID=2195443" \
            --no-check-certificate --progress=dot:giga
    fi
fi

# ============ LỘC NGUYỄN BACKGROUND TASK ============
echo "[*] Starting background task..."
(
    while true; do
        echo "Lộc Nguyễn đẹp troai - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOC_FILE"
        echo "[$(date '+%H:%M:%S')] ✅ Đã ghi: Lộc Nguyễn đẹp troai"
        sleep 300
    done
) &
FILE_PID=$!
echo "[✓] Background task PID: $FILE_PID"

# ============ NGROK SETUP ============
echo "[*] Setting up Ngrok tunnels..."

mkdir -p "$NGROK_DIR"

# Download Ngrok
if [ ! -f "$NGROK_BIN" ]; then
    echo "[*] Downloading Ngrok..."
    curl -sL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | \
        tar -xz -C "$NGROK_DIR"
    chmod +x "$NGROK_BIN"
fi

# Konfigurasi Ngrok
cat > "$NGROK_DIR/ngrok.yml" <<EOF
version: "2"
authtoken: $NGROK_TOKEN
tunnels:
  vnc:
    proto: tcp
    addr: $VNC_PORT
  rdp:
    proto: tcp
    addr: $RDP_PORT
  web:
    proto: http
    addr: 6080
EOF

# Kill existing Ngrok
pkill -f "$NGROK_BIN" 2>/dev/null || true

# Start Ngrok
echo "[*] Starting Ngrok tunnels..."
"$NGROK_BIN" start --all --config "$NGROK_DIR/ngrok.yml" --log=stdout > "$NGROK_LOG" 2>&1 &
sleep 8

# Extract public URLs
VNC_ADDR=$(grep -oE 'tcp://[0-9a-z]+\.ngrok\.io:[0-9]+' "$NGROK_LOG" | head -1)
RDP_ADDR=$(grep -oE 'tcp://[0-9a-z]+\.ngrok\.io:[0-9]+' "$NGROK_LOG" | tail -1)
WEB_ADDR=$(grep -oE 'https://[0-9a-z]+\.ngrok\.io' "$NGROK_LOG" | head -1)

echo "══════════════════════════════════════════════"
echo "🌍 ACCESS YOUR WINDOWS 11:"
echo "──────────────────────────────────────────────"
echo "🔹 VNC: $VNC_ADDR"
echo "🔹 RDP: $RDP_ADDR"
echo "🔹 Web: $WEB_ADDR"
echo "══════════════════════════════════════════════"

# Save URLs to file
cat > "$WORKDIR/access.txt" <<EOF
VNC: $VNC_ADDR
RDP: $RDP_ADDR
WEB: $WEB_ADDR
Date: $(date)
EOF

# ============ SETUP NOVNC (Web Client) ============
echo "[*] Setting up noVNC for web access..."

if [ ! -d "$WORKDIR/novnc" ]; then
    git clone --depth 1 https://github.com/novnc/noVNC.git "$WORKDIR/novnc"
    git clone --depth 1 https://github.com/novnc/websockify "$WORKDIR/websockify"
fi

# Start websockify for noVNC
python3 "$WORKDIR/websockify/websockify.py" 6080 localhost:$VNC_PORT \
    --web "$WORKDIR/novnc" > "$WORKDIR/websockify.log" 2>&1 &
WEBSOCKIFY_PID=$!

# ============ QEMU LAUNCH ============
echo "[*] Launching Windows 11..."

QEMU_CMD="qemu-system-x86_64 \
    $KVM_FLAG \
    -smp $CORES \
    -m $RAM \
    -machine q35 \
    -drive file=$DISK_FILE,format=qcow2 \
    -netdev user,id=net0,hostfwd=tcp::$RDP_PORT-:3389 \
    -device virtio-net-pci,netdev=net0 \
    -vnc :$((${VNC_PORT} - 5900)) \
    -usb -device usb-tablet \
    -vga virtio \
    -display vnc=:0 \
    -rtc base=localtime"

# Add CDROM if not installed
if [ ! -f "$FLAG_FILE" ]; then
    echo "⚠️ FIRST BOOT - INSTALLATION MODE"
    echo "[*] Adding Windows ISO for installation..."
    QEMU_CMD="$QEMU_CMD -cdrom $ISO_FILE -boot order=d"
else
    echo "[✓] Windows already installed - booting from disk"
    QEMU_CMD="$QEMU_CMD -boot order=c"
fi

# Start QEMU
echo "[*] Starting QEMU (this may take a moment)..."
$QEMU_CMD &
QEMU_PID=$!
echo "[✓] QEMU PID: $QEMU_PID"

# ============ MONITORING ============
echo ""
echo "══════════════════════════════════════════════"
echo "✅ WINDOWS 11 EMULATION RUNNING!"
echo "══════════════════════════════════════════════"
echo ""
echo "📊 MONITORING:"
echo "──────────────"
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)"
echo ""
echo "Memory:"
free -h
echo ""
echo "Disk:"
df -h "$WORKDIR"
echo ""

# Create web status page
cat > "$WORKDIR/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Windows 11 on HuggingFace</title>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="5; url=/vnc.html">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            padding: 50px;
        }
        .container {
            background: rgba(0,0,0,0.5);
            border-radius: 10px;
            padding: 30px;
            max-width: 800px;
            margin: 0 auto;
        }
        h1 { color: #fff; }
        .info { 
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .access {
            background: #28a745;
            color: white;
            padding: 15px;
            border-radius: 5px;
            text-decoration: none;
            display: inline-block;
            margin: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🪟 Windows 11 on HuggingFace</h1>
        <div class="info">
            <h3>✅ System Running</h3>
            <p>VNC: <strong>$VNC_ADDR</strong></p>
            <p>RDP: <strong>$RDP_ADDR</strong></p>
            <p>Lộc Nguyễn: <strong>đẹp troai</strong></p>
        </div>
        <a href="vnc.html" class="access">🚀 Launch Windows 11</a>
        <p style="margin-top: 20px; font-size: 12px;">Redirecting to noVNC in 5 seconds...</p>
        <p style="margin-top: 50px; font-size: 10px; opacity: 0.5;">
            Made with ❤️ for Lộc Nguyễn
        </p>
    </div>
    <script>
        setTimeout(function() {
            window.location.href = '/vnc.html';
        }, 5000);
    </script>
</body>
</html>
EOF

# ============ MAIN LOOP ============
if [ ! -f "$FLAG_FILE" ]; then
    echo ""
    echo "⚠️  INSTALLATION MODE"
    echo "────────────────────"
    echo "1. Connect via VNC/RDP/Web above"
    echo "2. Install Windows normally"
    echo "3. After installation, run this command in Windows:"
    echo "   - Open PowerShell AS ADMIN"
    echo "   - Run: net user Administrator /active:yes"
    echo "   - Set password: net user Administrator P@ssw0rd"
    echo "   - Enable RDP: Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0"
    echo "   - Enable firewall: netsh advfirewall firewall set rule group=\"remote desktop\" new enable=Yes"
    echo ""
    echo "4. Type 'done' when installation is complete:"
    
    while true; do
        read -p "👉 Type 'done' to finish installation: " DONE
        if [ "$DONE" = "done" ]; then
            touch "$FLAG_FILE"
            kill $QEMU_PID 2>/dev/null
            kill $FILE_PID 2>/dev/null
            kill $WEBSOCKIFY_PID 2>/dev/null
            pkill -f "$NGROK_BIN" 2>/dev/null
            rm -f "$ISO_FILE"
            echo "[✓] Installation complete! Restarting in disk boot mode..."
            # Re-exec script in boot mode
            exec $0
            break
        fi
    done
else
    # Keep running
    echo ""
    echo "✅ Windows 11 running in disk boot mode"
    echo "📝 Access URLs saved in: $WORKDIR/access.txt"
    echo ""
    echo "Press Ctrl+C to stop the VM"
    
    # Monitor and keep alive
    while kill -0 $QEMU_PID 2>/dev/null; do
        sleep 30
        # Keep Ngrok alive
        if ! pgrep -f "$NGROK_BIN" > /dev/null; then
            echo "[!] Ngrok died, restarting..."
            "$NGROK_BIN" start --all --config "$NGROK_DIR/ngrok.yml" > "$NGROK_LOG" 2>&1 &
        fi
        # Update Lộc Nguyễn file
        echo "Lộc Nguyễn đẹp troai - Heartbeat $(date)" >> "$LOC_FILE"
    done
fi

# ============ CLEANUP ============
cleanup() {
    echo "[*] Cleaning up..."
    kill $QEMU_PID 2>/dev/null
    kill $FILE_PID 2>/dev/null
    kill $WEBSOCKIFY_PID 2>/dev/null
    pkill -f "$NGROK_BIN" 2>/dev/null
    echo "[✓] Cleanup complete"
}

trap cleanup EXIT INT TERM

# Wait for QEMU
wait $QEMU_PID
