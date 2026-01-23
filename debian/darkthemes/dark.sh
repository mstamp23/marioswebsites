#!/bin/bash
# Dark Professional Theme Setup for XFCE - Debian 13
# Focus: True Black, Snappy, Native, Professional

set -e
trap 'echo "Error on line $LINENO"; exit 1' ERR

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Get the actual user who called sudo
REAL_USER=${SUDO_USER:-$USER}

echo "Installing core dependencies..."
apt update
apt install -y --no-install-recommends \
    papirus-icon-theme \
    fonts-dejavu \
    gtk2-engines-murrine \
    gtk2-engines-pixbuf \
    xfconf

THEME_DIR="/usr/share/themes/Xfce-Dark-Pro"
mkdir -p "$THEME_DIR/gtk-2.0" "$THEME_DIR/gtk-3.0" "$THEME_DIR/xfwm4"

echo "Creating GTK 2.0 assets..."
cat > "$THEME_DIR/gtk-2.0/gtkrc" <<'EOF'
gtk-color-scheme = "fg_color:#eeeeee\nbg_color:#121212\nbase_color:#000000\ntext_color:#eeeeee\nselected_bg_color:#005fb8\nselected_fg_color:#ffffff"
include "apps/panel.rc" # Optional: can add specific panel styling here
style "default" {
    bg[NORMAL] = "#121212"
    base[NORMAL] = "#000000"
    text[NORMAL] = "#eeeeee"
    fg[NORMAL] = "#eeeeee"
}
class "GtkWidget" style "default"
EOF

echo "Creating GTK 3.0 assets (Professional & Safe)..."
cat > "$THEME_DIR/gtk-3.0/gtk.css" <<'EOF'
/* Professional Dark Base */
@define-color theme_bg_color #121212;
@define-color theme_fg_color #eeeeee;
@define-color theme_base_color #000000;
@define-color theme_text_color #eeeeee;
@define-color theme_selected_bg_color #005fb8;
@define-color theme_selected_fg_color #ffffff;

window, grid, stack { background-color: @theme_bg_color; color: @theme_fg_color; }
headerbar, .titlebar { background-color: @theme_bg_color; color: @theme_fg_color; border-bottom: 1px solid #222; }
entry { background-color: @theme_base_color; color: @theme_text_color; border: 1px solid #333; }
button { background-image: none; background-color: #222; color: #eee; border: 1px solid #333; }
button:hover { background-color: #333; }
button:checked, button:active { background-color: @theme_selected_bg_color; }
EOF

echo "Creating Xfwm4 (Window Title Bar) theme..."
# This makes the top bar of windows black
cat > "$THEME_DIR/xfwm4/themerc" <<'EOF'
active_text_color=#ffffff
inactive_text_color=#888888
active_color_1=#121212
inactive_color_1=#121212
button_offset=8
button_spacing=1
title_vertical_offset_active=0
title_vertical_offset_inactive=0
title_shadow=none
EOF

# Apply settings globally for new users
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Xfce-Dark-Pro"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="FontName" type="string" value="DejaVu Sans 10"/>
  </property>
</channel>
EOF

echo "Applying to current user: $REAL_USER"
# This runs the config change as the actual user so it takes effect immediately
sudo -u "$REAL_USER" xfconf-query -c xsettings -p /Net/ThemeName -s "Xfce-Dark-Pro" || true
sudo -u "$REAL_USER" xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" || true
sudo -u "$REAL_USER" xfconf-query -c xfwm4 -p /general/theme -s "Xfce-Dark-Pro" || true

echo "Done! Restart XFCE or re-log to see full effects."
