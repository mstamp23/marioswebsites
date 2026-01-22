#!/bin/bash
# ============================================================================
# DEBIAN 13 (TRIXIE) - THE "IRONCLAD" INSTALLER
# Fix: Keyboard "Access Denied" & zRAM service race condition
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# 1. LOGGING & ROOT CHECK
mkdir -p /var/log
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1
if [ "$EUID" -ne 0 ]; then echo "❌ Run as root"; exit 1; fi

# 2. CORE TOOLS & USER (Password: 1)
echo "📦 Setting up user and base tools..."
apt update
apt install -y sudo wget ca-certificates
mkdir -p /etc/sudoers.d

if ! id -u m &>/dev/null; then
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd
fi

echo 'm ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/m
chmod 0440 /etc/sudoers.d/m
adduser m sudo || true

# 3. SOURCES (Trixie + Non-Free)
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
apt update && apt upgrade -y

# 4. HARDWARE: i9 & NVIDIA
echo "🔧 Configuring Hardware..."
apt install -y intel-microcode thermald linux-headers-amd64
systemctl enable thermald || true

if lspci | grep -qi nvidia; then
    echo "🎮 NVIDIA GPU Detected. Installing drivers..."
    apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings
    mkdir -p /etc/X11/xorg.conf.d/
    cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
fi

# 5. RAM OPTIMIZATION
echo "💾 Configuring RAM & SSD..."
apt install -y zram-tools smartmontools
sleep 2 
if [ -f /etc/default/zram-tools ]; then
    echo "ALGO=zstd" > /etc/default/zram-tools
    echo "PERCENT=25" >> /etc/default/zram-tools
fi
echo "vm.swappiness=10" >> /etc/sysctl.conf

# 6. LOCALES & KEYBOARD (DIRECT FILE ACCESS FIX)
echo "🌐 Setting Locales & Keyboard (Direct Fix)..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Bypassing localectl to avoid "Access Denied"
cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,gr"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

# 7. CHROME & XFCE DESKTOP
echo "🖥️ Installing Desktop and Apps..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
apt install -y /tmp/google-chrome-stable_current_amd64.deb || true

apt install -y --no-install-recommends \
    xfce4 xfce4-terminal thunar xfce4-settings xfce4-panel xfce4-session \
    xfce4-power-manager network-manager-gnome lightdm lightdm-gtk-greeter \
    fonts-inter pavucontrol rclone vlc firefox-esr qbittorrent yt-dlp flameshot

# 8. FINAL CLEANUP
apt autoremove -y
chown -R m:m /home/m/
update-grub

echo "=========================================="
echo "✅ SUCCESS! REBOOTING IN 5 SECONDS..."
echo "=========================================="
sleep 5
reboot
