#!/bin/bash
# Minimal XFCE for HP Pavilion - Debian 13 (Trixie)
# Error handling and root check

set -e  # Exit on any error
trap 'echo "Error on line $LINENO. Exiting."; exit 1' ERR

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "This script must be run as root. Use: sudo bash script.sh"
   exit 1
fi

echo "Starting XFCE installation for HP Pavilion..."

# 1. Enable Non-Free Firmware Repositories
echo "[1/5] Enabling non-free firmware repositories..."
sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list 2>/dev/null || true
# For newer Debian 13 installs using the .sources format:
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
fi

# 2. Update and Install Core System
echo "[2/5] Updating system and installing core packages..."
apt update || { echo "apt update failed"; exit 1; }
apt upgrade -y || { echo "apt upgrade failed"; exit 1; }

apt install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg xinit \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 thunar xfce4-terminal xfce4-settings \
    xfce4-whiskermenu-plugin xfce4-power-manager xfce4-notifyd \
    network-manager-gnome pulseaudio pavucontrol mousepad \
    thunar-archive-plugin || { echo "Core package installation failed"; exit 1; }

# 3. Install HP Pavilion WiFi & Bluetooth Firmware
echo "[3/5] Installing firmware packages..."
apt install -y --no-install-recommends \
    firmware-iwlwifi firmware-realtek firmware-atheros firmware-libertas firmware-brcm80211 \
    2>/dev/null || { echo "Warning: Some firmware packages unavailable (non-critical, continuing...)"; }

# 4. Set Workspaces to 1 (System-wide default)
echo "[4/5] Configuring XFCE workspace settings..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml || { echo "Failed to create xfce config directory"; exit 1; }
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="workspace_count" type="int" value="1"/>
  </property>
</channel>
EOF

if [ $? -ne 0 ]; then
    echo "Failed to write XFCE config"
    exit 1
fi

# 5. Enable Login Screen and Finish
echo "[5/5] Enabling LightDM login manager..."
systemctl enable lightdm || { echo "Failed to enable lightdm"; exit 1; }

echo ""
echo "================================"
echo "Installation complete!"
echo "================================"
echo "Rebooting in 5 seconds..."
sleep 5
reboot
