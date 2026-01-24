#!/bin/bash
# Greybird-Dark Setup for XFCE - Debian 13
# Focus: Reliable, Native, Eye-Friendly, Professional

set -e

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Get the actual user who called sudo
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# --- Define Function First ---
run_as_user() {
    sudo -u "$REAL_USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$REAL_USER")/bus "$@"
}

echo "Step 1: Cleaning up..."
rm -rf /usr/share/themes/Xfce-Dark-Pro

echo "Step 2: Installing Greybird, Whisker Menu, and Icons..."
apt update
apt install -y \
    greybird-gtk-theme \
    papirus-icon-theme \
    xfce4-whiskermenu-plugin \
    fonts-dejavu \
    xfconf

echo "Step 3: Setting Global Defaults for new users..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Greybird-dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="FontName" type="string" value="DejaVu Sans 10"/>
  </property>
</channel>
EOF

echo "Step 4: Applying to current user: $REAL_USER"

# Apply UI Theme, Icons, and Window Borders
run_as_user xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird-dark" || true
run_as_user xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" || true
run_as_user xfconf-query -c xfwm4 -p /general/theme -s "Greybird-dark" || true

# Set Windows Key (Super) to open Whisker Menu
run_as_user xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>_L" -n -t string -s "xfce4-popup-whiskermenu" || true

# Optional: Set the Whisker Menu to use the Dark theme specifically 
# (This logic finds the plugin ID automatically)
PLUGIN_ID=$(run_as_user xfconf-query -c xfce4-panel -p /plugins -lv | grep whiskermenu | cut -d' ' -f1 || echo "")
if [ -n "$PLUGIN_ID" ]; then
    run_as_user xfconf-query -c xfce4-panel -p "/plugins/$PLUGIN_ID/view-mode" -n -t int -s 1 || true
fi

echo "-------------------------------------------------------"
echo "Done! Greybird-dark and Whisker Menu are ready."
echo "Press the 'Windows' key to test your new menu!"
echo "-------------------------------------------------------"
