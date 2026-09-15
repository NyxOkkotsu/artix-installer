#!/bin/bash
set -euo pipefail

# ============================================================
# ARTIX LINUX - MINIMAL HYPRLAND HARDENED INSTALLER
# ============================================================
# Init       : OpenRC
# Kernel     : linux-hardened
# GPU        : AMDGPU + Mesa + RADV
# Network    : NetworkManager + iwd
# Bluetooth  : BlueZ
# Firewall   : UFW
# Display    : SDDM
# WM         : Hyprland
# Terminal   : Kitty
# Shell      : Fish
# Printing   : CUPS
# Scanning   : SANE
# Filesystem : ext4
# Disk       : NVMe /dev/nvme0n1
# ============================================================

set +H

DISK="/dev/nvme0n1"
EFI="${DISK}p1"
ROOT="${DISK}p2"
MNT="/mnt"

HOSTNAME="NyxArtix"
USERNAME="nyxokkotsu"
PASSWORD='frscompauth'

echo "============================================================"
echo "          ARTIX LINUX MINIMAL HARDENED INSTALLER"
echo "============================================================"
echo
echo "Target disk : ${DISK}"
echo "Filesystem  : ext4"
echo "Kernel      : linux-hardened"
echo "GPU         : AMDGPU + Mesa + RADV"
echo "Network     : NetworkManager + iwd"
echo "Bluetooth   : BlueZ"
echo "Firewall    : UFW"
echo "Display     : SDDM"
echo "Window mgr  : Hyprland"
echo "Terminal    : Kitty"
echo "Shell       : Fish"
echo "Printing    : CUPS"
echo "Scanning    : SANE"
echo "Init system : OpenRC"
echo

read -rp "Type YES to completely erase ${DISK}: " CONFIRM

if [[ "${CONFIRM}" != "YES" ]]; then
    echo "Installation cancelled."
    exit 1
fi

# ============================================================
# CLOCK
# ============================================================

echo "[1/14] Synchronizing system clock..."

timedatectl set-ntp true

# ============================================================
# PARTITIONING
# ============================================================

echo "[2/14] Partitioning NVMe drive..."

wipefs -af "${DISK}"
sgdisk --zap-all "${DISK}"

sgdisk \
    -n 1:0:+512M \
    -t 1:ef00 \
    -c 1:"EFI" \
    "${DISK}"

sgdisk \
    -n 2:0:0 \
    -t 2:8300 \
    -c 2:"ROOT" \
    "${DISK}"

partprobe "${DISK}"
sleep 2

# ============================================================
# FILESYSTEM
# ============================================================

echo "[3/14] Creating filesystems..."

mkfs.fat -F32 "${EFI}"
mkfs.ext4 -F -L ARTIX_ROOT "${ROOT}"

# ============================================================
# MOUNT
# ============================================================

echo "[4/14] Mounting filesystems..."

mount "${ROOT}" "${MNT}"

mkdir -p "${MNT}/boot/efi"
mount "${EFI}" "${MNT}/boot/efi"

# ============================================================
# BASE SYSTEM
# ============================================================

echo "[5/14] Installing hardened base system..."

basestrap "${MNT}" \
    base \
    base-devel \
    openrc \
    eudev \
    linux-hardened \
    linux-hardened-headers \
    linux-firmware \
    amd-ucode \
    grub \
    efibootmgr \
    sudo \
    fish \
    git \
    curl \
    wget \
    nano \
    vim \
    less \
    which \
    unzip \
    zip \
    tar \
    rsync \
    btop \
    fastfetch \
    pciutils \
    usbutils \
    iproute2 \
    ethtool \
    bind \
    traceroute \
    openssh

# ============================================================
# AMD GRAPHICS + HYPRLAND
# ============================================================

echo "[6/14] Installing AMD graphics stack and Hyprland..."

basestrap "${MNT}" \
    mesa \
    lib32-mesa \
    vulkan-radeon \
    lib32-vulkan-radeon \
    libva-mesa-driver \
    mesa-vdpau \
    xf86-video-amdgpu \
    wayland \
    wayland-protocols \
    xorg-xwayland \
    qt5-wayland \
    qt6-wayland \
    hyprland \
    kitty

# ============================================================
# DISPLAY MANAGER + DESKTOP SUPPORT
# ============================================================

echo "[7/14] Installing display and session components..."

basestrap "${MNT}" \
    sddm \
    sddm-openrc \
    dbus \
    dbus-openrc \
    elogind \
    elogind-openrc \
    seatd \
    seatd-openrc \
    polkit \
    polkit-kde-agent \
    xdg-desktop-portal \
    xdg-desktop-portal-hyprland

# ============================================================
# AUDIO
# ============================================================

echo "[8/14] Installing PipeWire audio stack..."

basestrap "${MNT}" \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    alsa-utils \
    pavucontrol

# ============================================================
# NETWORK
# ============================================================

echo "[9/14] Installing NetworkManager with iwd backend..."

basestrap "${MNT}" \
    networkmanager \
    networkmanager-openrc \
    iwd

# ============================================================
# BLUETOOTH
# ============================================================

echo "[10/14] Installing Bluetooth stack..."

basestrap "${MNT}" \
    bluez \
    bluez-utils \
    bluez-openrc \
    blueman

# ============================================================
# FIREWALL
# ============================================================

echo "[11/14] Installing firewall..."

basestrap "${MNT}" \
    ufw

# ============================================================
# PRINTING / SCANNING / DEVICE DISCOVERY
# ============================================================

echo "[12/14] Installing printing and scanning services..."

basestrap "${MNT}" \
    cups \
    cups-openrc \
    cups-pdf \
    system-config-printer \
    sane \
    sane-airscan \
    ipp-usb \
    avahi \
    avahi-openrc \
    nss-mdns

# ============================================================
# HARDWARE / POWER / NVMe
# ============================================================

echo "[13/14] Installing hardware, NVMe and power utilities..."

basestrap "${MNT}" \
    nvme-cli \
    smartmontools \
    lm_sensors \
    acpi \
    acpid \
    acpid-openrc \
    powertop \
    fwupd \
    fwupd-openrc

# ============================================================
# BASIC SYSTEM APPLICATIONS
# ============================================================

echo "[14/14] Installing essential desktop utilities..."

basestrap "${MNT}" \
    firefox \
    thunar \
    file-roller \
    network-manager-applet

# ============================================================
# FSTAB
# ============================================================

echo "Generating filesystem table..."

fstabgen -U "${MNT}" >> "${MNT}/etc/fstab"

# ============================================================
# CHROOT CONFIGURATION
# ============================================================

echo "Configuring installed system..."

artix-chroot "${MNT}" /bin/bash <<EOF

set -e

# ------------------------------------------------------------
# TIMEZONE
# ------------------------------------------------------------

echo "Configuring timezone..."

ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

# ------------------------------------------------------------
# LOCALE
# ------------------------------------------------------------

echo "Configuring locale..."

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#id_ID.UTF-8 UTF-8/id_ID.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

cat > /etc/locale.conf <<EOL
LANG=en_US.UTF-8
LC_TIME=id_ID.UTF-8
EOL

# ------------------------------------------------------------
# HOSTNAME
# ------------------------------------------------------------

echo "Configuring hostname..."

echo "${HOSTNAME}" > /etc/hostname

cat > /etc/hosts <<EOL
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOL

# ------------------------------------------------------------
# ROOT PASSWORD
# ------------------------------------------------------------

echo "Configuring root password..."

echo "root:${PASSWORD}" | chpasswd

# ------------------------------------------------------------
# USER
# ------------------------------------------------------------

echo "Creating user ${USERNAME}..."

useradd \
    -m \
    -G wheel,video,audio,input,storage,optical,lp,seat \
    -s /usr/bin/fish \
    "${USERNAME}"

echo "${USERNAME}:${PASSWORD}" | chpasswd

# ------------------------------------------------------------
# FULL ADMIN ACCESS
# ------------------------------------------------------------

echo "Granting full administrative privileges..."

cat > "/etc/sudoers.d/10-${USERNAME}" <<EOL
${USERNAME} ALL=(ALL:ALL) ALL
EOL

chmod 440 "/etc/sudoers.d/10-${USERNAME}"

# ------------------------------------------------------------
# FISH
# ------------------------------------------------------------

echo "Setting Fish as the default shell..."

chsh -s /usr/bin/fish "${USERNAME}"

# ------------------------------------------------------------
# NETWORKMANAGER + IWD
# ------------------------------------------------------------

echo "Configuring NetworkManager..."

mkdir -p /etc/NetworkManager

cat > /etc/NetworkManager/NetworkManager.conf <<EOL
[main]
plugins=keyfile

[device]
wifi.backend=iwd

[connection]
wifi.powersave=3
EOL

# ------------------------------------------------------------
# IWD
# ------------------------------------------------------------

echo "Configuring iwd..."

mkdir -p /etc/iwd

cat > /etc/iwd/main.conf <<EOL
[General]
EnableNetworkConfiguration=false

[Network]
EnableIPv6=true
EOL

# ------------------------------------------------------------
# SDDM
# ------------------------------------------------------------

echo "Configuring SDDM..."

mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/10-display.conf <<EOL
[General]
DisplayServer=wayland
EOL

# ------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------

echo "Configuring environment..."

cat > /etc/environment <<EOL
EDITOR=nano
VISUAL=nano
EOL

# ------------------------------------------------------------
# SYSCTL HARDENING
# ------------------------------------------------------------

echo "Applying basic kernel hardening..."

mkdir -p /etc/sysctl.d

cat > /etc/sysctl.d/99-nyx-hardening.conf <<EOL
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
EOF

# ------------------------------------------------------------
# OPENRC SERVICES
# ------------------------------------------------------------

echo "Enabling OpenRC services..."

enable_service() {
    if rc-service "\$1" status >/dev/null 2>&1 || \
       [ -x "/etc/init.d/\$1" ]; then
        rc-update add "\$1" default || true
    fi
}

enable_service dbus
enable_service elogind
enable_service seatd

enable_service NetworkManager
enable_service iwd

enable_service bluetooth
enable_service sddm

enable_service cups
enable_service avahi

enable_service acpid
enable_service fwupd

# ------------------------------------------------------------
# UFW
# ------------------------------------------------------------

echo "Configuring UFW..."

ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# ------------------------------------------------------------
# GRUB
# ------------------------------------------------------------

echo "Installing GRUB..."

grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=Artix \
    --recheck

grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------
# USER DIRECTORIES
# ------------------------------------------------------------

echo "Creating user directories..."

su - "${USERNAME}" -c '
mkdir -p \
    ~/Desktop \
    ~/Documents \
    ~/Downloads \
    ~/Music \
    ~/Pictures \
    ~/Videos
'

EOF

# ============================================================
# FINALIZE
# ============================================================

echo "Finalizing installation..."

sync

umount -R "${MNT}"

sync

echo
echo "============================================================"
echo "             ARTIX LINUX INSTALLATION COMPLETE"
echo "============================================================"
echo
echo "Username     : ${USERNAME}"
echo "Password     : ${PASSWORD}"
echo "Default shell: Fish"
echo "Admin access : Full sudo access"
echo "Kernel       : linux-hardened"
echo "GPU          : AMDGPU / Mesa / RADV"
echo "Network      : NetworkManager / iwd"
echo "Bluetooth    : BlueZ"
echo "Firewall     : UFW"
echo "Printing     : CUPS"
echo "Scanning     : SANE"
echo "Desktop      : Hyprland"
echo "Terminal     : Kitty"
echo "Display      : SDDM"
echo "Init         : OpenRC"
echo "Filesystem   : ext4"
echo "Disk         : ${DISK}"
echo
echo "The system is ready to reboot."
echo "============================================================"
echo

read -rp "Reboot now? [y/N]: " REBOOT

if [[ "${REBOOT}" =~ ^[Yy]$ ]]; then
    reboot
fi
