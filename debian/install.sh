#!/bin/bash
# Minimal XFCE for HP Pavilion - Debian 13 (Trixie)
set -e
trap 'echo "Error on line $LINENO. Exiting."; exit 1' ERR
if [ "$EUID" -ne 0 ]; then
   echo "This script must be run as root. Use: sudo bash script.sh"
   exit 1
fi
echo "Starting XFCE installation for HP Pavilion..."
# 0. Install Sudo and Configure User "m"
echo "[0/6] Installing sudo and adding user 'm' to sudoers..."
apt update
apt install -y sudo
if id "m" &>/dev/null; then
    echo "User 'm' already exists."
else
    echo "Creating user 'm'..."
    useradd -m -s /bin/bash m
    echo "Please set a password for user 'm':"
    passwd m
fi
usermod -aG sudo m
echo "User 'm' added to sudoers."
# 1. Enable Non-Free Firmware Repositories
echo "[1/6] Configuring repositories..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    # Removed $ to ensure it matches even with trailing spaces
    sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.backup
    sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
fi
# 2. Update and Install Core System
echo "[2/6] Installing XFCE Desktop..."
apt update
apt upgrade -y
apt install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg xinit \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 thunar xfce4-terminal xfce4-settings \
    xfce4-whiskermenu-plugin xfce4-power-manager xfce4-notifyd \
    network-manager-gnome pulseaudio pavucontrol mousepad \
    thunar-archive-plugin gvfs gvfs-backends
# 3. Install HP Pavilion WiFi & Bluetooth Firmware
echo "[3/6] Installing firmware..."
apt install -y --no-install-recommends \
    firmware-linux-nonfree firmware-iwlwifi firmware-realtek \
    firmware-atheros firmware-libertas firmware-brcm80211 || echo "Warning: Firmware failed."
# 4. Set Workspaces to 1
echo "[4/6] Setting workspace count..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="workspace_count" type="int" value="1"/>
  </property>
</channel>
EOF
# 5. Enable Login Screen
systemctl enable lightdm
# 6. Finalize
echo "================================"
echo "Installation complete!"
echo "Rebooting in 2 seconds..."
sleep 2
reboot
