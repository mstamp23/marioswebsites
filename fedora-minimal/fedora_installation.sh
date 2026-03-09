sudo dnf install @xfce-desktop-environment -y   
sudo systemctl set-default graphical.target   
reboot


sudo dnf install -y \
@xfce-desktop-environment \
gnome-keyring \
firefox \
chromium \
ffmpeg \
gstreamer1-plugins-{base,good,bad-free,bad-freeworld,ugly} \
gstreamer1-libav \
pulseaudio \
pulseaudio-utils \
alsa-plugins-pulseaudio \
libdvdcss \
rpmfusion-free-release \
rpmfusion-nonfree-release \
vlc \
wget \
curl \
unrar \
p7zip \
fonts-freetype \
fonts-dejavu \
libvpx \
libx264 \
mesa-dri-drivers \
mesa-vulkan-drivers \
mesa-libGL \
mesa-libGLU \
xorg-x11-drv-{intel,nouveau,vesa} \
NetworkManager-tui \
nano
