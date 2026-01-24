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
REAL_HOME=$(eval echo ~$REAL_USER)

echo "Step 1: Removing old problematic custom theme..."
rm -rf /usr/share/themes/Xfce-Dark-Pro

echo "Step 2: Installing Greybird and Core Dependencies..."
apt update
apt install -y \
    greybird-gtk-theme \
    papirus-icon-theme \
    fonts-dejavu \
    xfconf

echo "Step 3: Verifying theme installation..."
if [ ! -d "/usr/share/themes/Greybird-dark" ]; then
    echo "Error: Greybird-dark theme not found after installation"
    exit 1
fi

if [ ! -d "/usr/share/icons/Papirus-Dark" ]; then
    echo "Warning: Papirus-Dark not found, using Papirus instead"
    ICON_THEME="Papirus"
else
    ICON_THEME="Papirus-Dark"
fi

echo "Step 4: Setting Greybird-dark as default for new users..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml

cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Greybird-dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
</channel>
EOF

echo "Step 5: Applying to current user: $REAL_USER..."

# Apply the UI theme
sudo -u "$REAL_USER" xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird-dark" 2>/dev/null || \
    echo "Warning: Could not set UI theme for current user"

# Apply the Window Borders
sudo -u "$REAL_USER" xfconf-query -c xfwm4 -p /general/theme -s "Greybird-dark" 2>/dev/null || \
    echo "Warning: Could not set window borders for current user"

# Apply the Icons
sudo -u "$REAL_USER" xfconf-query -c xsettings -p /Net/IconThemeName -s "$ICON_THEME" 2>/dev/null || \
    echo "Warning: Could not set icon theme for current user"

echo "-------------------------------------------------------"
echo "✓ Setup complete! Greybird-dark is now active."
echo "  - UI Theme: Greybird-dark"
echo "  - Icon Theme: $ICON_THEME"
echo "  - Window Manager: Greybird-dark"
echo ""
echo "If changes don't appear:"
echo "  1. Log out and log back in"
echo "  2. Or restart xfce4-panel: pkill xfpanel"
echo "-------------------------------------------------------"
