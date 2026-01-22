#!/bin/bash

# ============================================================================
# DEBIAN 13 (TRIXIE) STABLE - COMPLETE AUTOMATED INSTALLER
# Optimized for: i9-13900F / NVIDIA GTX 1650 / 64GB RAM / 980 PRO SSD
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# 1. LOGGING & ROOT CHECK
mkdir -p /var/log /home/m/launchers /home/m/My-Drive
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1
echo "🚀 Starting Debian 13 STABLE Installation - $(date)"

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root"
    exit 1
fi

# 2. USER SETUP
echo "👤 Setting up user 'm'..."
if ! id -u m &>/dev/null; then
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd
fi
usermod -aG sudo,vboxsf m 2>/dev/null || usermod -aG sudo m

# Passwordless sudo for apt
mkdir -p /etc/sudoers.d
cat <<'EOF' > /etc/sudoers.d/m
m ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get
m ALL=(ALL) ALL
Defaults:m timestamp_timeout=30
EOF
chmod 0440 /etc/sudoers.d/m

# 3. SOURCES (Modern deb822-friendly format)
echo "📦 Configuring Debian 13 Stable repositories..."
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt upgrade -y

# 4. ESSENTIAL TOOLS (Fixed: software-properties-common REMOVED)
echo "🔧 Installing essential tools..."
# 'software-properties-common' is removed in Debian 13. We use gpg/curl instead.
apt install -y sudo wget ca-certificates unzip curl gnupg2 dirmngr lsb-release \
    apt-transport-https unattended-upgrades rclone build-essential git speedtest-cli \
    htop gparted ntfs-3g python3-venv python3-pip geany linux-headers-amd64

# 5. HARDWARE OPTIMIZATIONS
echo "⚡ Applying hardware optimizations..."
# Intel CPU
apt install -y intel-microcode thermald cpufrequtils
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

# NVIDIA GTX 1650
if lspci | grep -qi nvidia; then
    echo "🎮 Installing NVIDIA drivers..."
    apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings
    if ! systemd-detect-virt | grep -q 'oracle\|vmware\|qemu'; then
        mkdir -p /etc/X11/xorg.conf.d/
        cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
    fi
fi

# RAM & SSD
apt install -y zram-tools smartmontools
echo -e "ALGO=zstd\nPERCENT=25" > /etc/default/zram-tools
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo 'ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"' > /etc/udev/rules.d/60-scheduler.rules

# 6. XFCE DESKTOP & LOCALES
echo "🖥️ Installing XFCE and configuring Locales..."
apt install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter \
    xfce4-power-manager network-manager-gnome pavucontrol thunar locales

echo -e "en_US.UTF-8 UTF-8\nel_GR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Keyboard EN/GR
cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,gr"
XKBOPTIONS="grp:alt_shift_toggle"
EOF

# 7. APPLICATIONS
echo "📱 Installing applications..."
apt install -y firefox-esr vlc qbittorrent yt-dlp ffmpeg flameshot viber protonvpn-stable-release protonvpn-cli protonvpn-app || true

# Chrome manual install
wget -P /tmp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y /tmp/google-chrome-stable_current_amd64.deb || apt --fix-broken install -y

# 8. SECURITY & MAINTENANCE
apt install -y ufw fail2ban clamav
ufw default deny incoming
ufw --force enable

# Rclone Systemd Timer
cat <<EOF > /etc/systemd/system/rclone-sync.timer
[Unit]
Description=Daily Rclone Sync
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl enable rclone-sync.timer

# 9. FINAL CLEANUP
echo "🚀 Optimizing GRUB..."
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub
chown -R m:m /home/m/
apt autoremove -y

echo "✅ Installation finished. Rebooting in 10s..."
sleep 10
reboot
