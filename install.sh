#!/bin/bash

# --- ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then echo "Please run as root"; exit; fi
set -e 

echo "--- Starting Universal Debian 13 Professional Installation ---"

# 1. SOURCES & UPDATES
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt upgrade -y

# 2. LOCALES & KEYBOARD (English Menus, Greek Typing)
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "el_GR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
localectl set-locale LANG=en_US.UTF-8
localectl set-x11-keymap us,gr pc105 ,grp:alt_shift_toggle

# 3. USER 'm' PRIVILEGES
echo 'm ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get' > /etc/sudoers.d/m
echo 'Defaults:m timestamp_timeout=30' >> /etc/sudoers.d/m
chmod 0440 /etc/sudoers.d/m

# 4. HARDWARE LOGIC (Intel/Nvidia/Beast)
if grep -q "Intel" /proc/cpuinfo; then
    apt install -y intel-microcode thermald
    systemctl enable thermald
elif grep -q "AMD" /proc/cpuinfo; then
    apt install -y amd64-microcode
fi

if lspci | grep -i nvidia; then
    apt install -y nvidia-detect linux-headers-amd64
    apt install -y $(nvidia-detect | grep -o 'nvidia-driver') firmware-misc-nonfree
fi

# RAM Optimization (zRAM & Tmp-in-RAM)
apt install -y zram-tools
echo "zram_size=8G" >> /etc/default/zram-tools
systemctl restart zram-tools
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

# 5. SECURITY & MAINTENANCE (Unattended Upgrades)
apt install -y unattended-upgrades ufw libpam-usb pamusb-tools clamtk
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=\${distro_codename}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
systemctl enable unattended-upgrades

# 6. RCLONE AUTOMATION (Service & Timer)
cat <<EOF > /etc/systemd/system/rclone-sync.service
[Unit]
Description=Daily Rclone Sync for user m
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=m
ExecStart=/usr/bin/rclone sync /home/m/My-Drive gdrive:My-Drive --exclude "venv/**" --exclude ".git/**"
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
EOF

cat <<EOF > /etc/systemd/system/rclone-sync.timer
[Unit]
Description=Run Rclone Sync every day at 03:00 AM

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable rclone-sync.timer

# 7. CHROME INSTALLATION (Official Google Repo)
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
apt install -y /tmp/google-chrome-stable_current_amd64.deb

# 8. MINT-STYLE DESKTOP & THEME
apt install -y --no-install-recommends xfce4 xfce4-terminal thunar \
xfce4-settings xfce4-panel xfce4-session xfce4-power-manager \
network-manager-gnome lightdm lightdm-gtk-greeter \
fonts-inter fonts-dejavu fonts-freefont-ttf pavucontrol

# 9. PROFESSIONAL SOFTWARE STACK
apt install -y firefox-esr qbittorrent vlc yt-dlp ffmpeg flameshot \
menulibre rclone geany cpufrequtils ntfs-3g hdparm
# KVM Virtualization
apt install -y --no-install-recommends qemu-system qemu-utils libvirt-daemon-system virt-manager
usermod -aG libvirt,kvm m

# 10. FINAL TWEAKS (Masking & Grub)
systemctl mask bluetooth.service cups.service cups-browsed.service
sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub

# Prepare folders
mkdir -p /home/m/My-Drive /home/m/launchers
chown -R m:m /home/m/

apt autoremove -y && apt autoclean

echo "--- INSTALLATION FINISHED ---"
