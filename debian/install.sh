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
echo "[0/7] Installing sudo and adding user 'm' to groups..."
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

# Add user 'm' to necessary groups for power, network, and sudo
usermod -aG sudo,powerdev,netdev m
groupadd -r autologin 2>/dev/null || true
usermod -aG autologin m

# 1. Enable Non-Free Firmware Repositories
echo "[1/7] Configuring repositories..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi

if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.backup
    sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
fi

# 2. Update and Install Core System + Power Management Fixes
echo "[2/7] Installing XFCE Desktop and Power Tools..."
apt update
apt upgrade -y
apt install -y --no-install-recommends \
    xserver-xorg-core xserver-xorg xinit \
    lightdm lightdm-gtk-greeter \
    xfce4-session xfwm4 xfce4-panel xfdesktop4 thunar xfce4-terminal xfce4-settings \
    xfce4-whiskermenu-plugin xfce4-power-manager xfce4-notifyd \
    network-manager-gnome pulseaudio pavucontrol mousepad \
    thunar-archive-plugin gvfs gvfs-backends dbus-x11 \
    policykit-1 upower acpi-support acpid

# 3. Install HP Pavilion WiFi & Bluetooth Firmware
echo "[3/7] Installing firmware..."
apt install -y --no-install-recommends \
    firmware-linux-nonfree firmware-iwlwifi firmware-realtek \
    firmware-atheros firmware-libertas firmware-brcm80211 || echo "Warning: Firmware failed."

# 4. Set Workspaces to 1
echo "[4/7] Setting workspace count..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="workspace_count" type="int" value="1"/>
  </property>
</channel>
EOF

# 5. Enable Login Screen and Autologin
echo "[5/7] Configuring LightDM and Autologin..."
mkdir -p /etc/lightdm/lightdm.conf.d/
cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf <<EOF
[Seat:*]
autologin-user=m
autologin-user-timeout=0
EOF

systemctl enable lightdm

# 6. Enable Tap-to-Click for HP Touchpad
echo "[6/7] Enabling Tap-to-Click..."
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/40-libinput.conf <<EOF
Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
EndSection
EOF

# 7. Final Power Fix: Polkit permissions
echo "[7/7] Applying final Polkit permissions..."
mkdir -p /etc/polkit-1/localauthority/50-local.d/
cat > /etc/polkit-1/localauthority/50-local.d/consolekit.pkla <<EOF
[Allow Shutdown and Reboot]
Identity=unix-user:m
Action=org.freedesktop.consolekit.system.stop;org.freedesktop.consolekit.system.restart;org.freedesktop.login1.reboot;org.freedesktop.login1.reboot-multiple-sessions;org.freedesktop.login1.power-off;org.freedesktop.login1.power-off-multiple-sessions
ResultAny=yes
ResultInactive=no
ResultActive=yes
EOF

# Finalize
echo "================================"
echo "Installation complete!"
echo "User 'm' configured with Autologin and Power Permissions."
echo "================================"
echo "Rebooting in 5 seconds..."
sleep 5
reboot
