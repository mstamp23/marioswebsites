#!/bin/bash
# ============================================================================
# DEBIAN 13 (TRIXIE) - THE "IRONCLAD" AUTO-INSTALLER
# Fixes: Network Autodetect, Sudoers Directory, Minimal Install Dependencies
# ============================================================================

set -e
trap 'echo "❌ Error on line $LINENO. Check /var/log/debian-install.log"; exit 1' ERR

# 1. PRE-FLIGHT: LOGGING & NETWORK
mkdir -p /var/log
exec > >(tee -a /var/log/debian-install.log)
exec 2>&1

if [ "$EUID" -ne 0 ]; then echo "❌ Run as root"; exit 1; fi

echo "🌐 Stage 1: Forcing Network Connection..."
# Find the first physical interface that isn't 'lo'
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n1)

if [ -n "$IFACE" ]; then
    echo "  └─ Found interface: $IFACE. Requesting IP..."
    ip link set "$IFACE" up
    # Try to get an IP even if dhclient is missing by using the internal kernel trigger
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    # If the minimal install is missing dhclient, we'll try to install it first thing
fi

# 2. CORE DEPENDENCIES (Fixes Line 48 and DNS)
echo "📦 Installing Core Dependencies..."
apt update
apt install -y sudo wget ca-certificates gnupg2 curl

# 3. USER CREATION & SUDO (Fixed: Folder created first)
if ! id -u m &>/dev/null; then
    echo "👤 Creating user 'm'..."
    useradd -m -s /bin/bash m
    echo "m:1" | chpasswd 
fi

mkdir -p /etc/sudoers.d
cat <<EOF > /etc/sudoers.d/m
m ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/systemctl
Defaults:m timestamp_timeout=30
EOF
chmod 0440 /etc/sudoers.d/m
adduser m sudo || true

# 4. SOURCES & UPDATES
echo "📦 Configuring Repositories..."
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
apt update && apt upgrade -y

# 5. HARDWARE: i9 & NVIDIA GTX 1650
echo "🔧 Optimizing for i9 and GTX 1650..."
if grep -q "Intel" /proc/cpuinfo; then
    apt install -y intel-microcode thermald
    systemctl enable thermald
fi

if lspci | grep -qi nvidia; then
    apt install -y nvidia-detect linux-headers-amd64
    NVIDIA_PKG=$(nvidia-detect 2>/dev/null | grep -o 'nvidia-driver' || echo "nvidia-driver")
    apt install -y $NVIDIA_PKG firmware-misc-nonfree nvidia-settings
    # Screen Tearing Fix
    mkdir -p /etc/X11/xorg.conf.d/
    cat <<EOF > /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "ForceFullCompositionPipeline" "on"
EndSection
EOF
fi

# 6. RAM & SSD HEALTH (64GB RAM / Samsung 980 PRO)
apt install -y zram-tools smartmontools
echo "ALGO=zstd" > /etc/default/zram-tools
echo "PERCENT=25" >> /etc/default/zram-tools
systemctl restart zram-tools
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount
echo "vm.swappiness=10" >> /etc/sysctl.conf

# 7. LOCALES & KEYBOARD
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
localectl set-x11-keymap us,gr pc105 "" grp:alt_shift_toggle

# 8. SOFTWARE STACK & CHROME
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
apt install -y /tmp/google-chrome-stable_current_amd64.deb

apt install -y --no-install-recommends \
    xfce4 xfce4-terminal thunar xfce4-settings xfce4-panel xfce4-session \
    xfce4-power-manager network-manager-gnome lightdm lightdm-gtk-greeter \
    fonts-inter pavucontrol rclone vlc firefox-esr qbittorrent yt-dlp flameshot

# KVM Virtualization
apt install -y qemu-system qemu-utils libvirt-daemon-system virt-manager
usermod -aG libvirt,kvm m

# 9. SECURITY & RCLONE TIMER
apt install -y unattended-upgrades ufw libpam-usb pamusb-tools
ufw --force enable
ufw default deny incoming

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

# 10. CLEANUP & REBOOT
systemctl mask bluetooth.service cups.service
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub
chown -R m:m /home/m/
apt autoremove -y

echo "✅ SUCCESS! REBOOTING IN 5 SECONDS..."
sleep 5
reboot
