#!/usr/bin/env bash
#
# Nyx Illogical Impulse For Init Freedom
# Artix Linux / OpenRC installer for end-4's Hyprland dots
#
# This installs the current end-4 repository without invoking its
# Arch/system-manager installer path.  It uses the upstream repo for
# configuration and local PKGBUILDs, while handling Artix/OpenRC setup here.
#
# Run as the normal desktop user, NOT as root.
# Requires: Artix Linux, pacman, sudo, git, makepkg, an active graphical session.
#

set -Eeuo pipefail

REPO='https://github.com/end-4/dots-hyprland.git'
BRANCH='main'
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nyx-end4-artix"
DOTS_DIR="$CACHE_DIR/dots-hyprland"
VENV_DIR="$HOME/.local/state/quickshell/.venv"

C_CYAN='\033[36m'; C_GREEN='\033[32m'; C_RED='\033[31m'; C_YELLOW='\033[33m'; C_RESET='\033[0m'
info(){ printf '%b[INFO]%b %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok(){ printf '%b[ OK ]%b %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn(){ printf '%b[WARN]%b %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die(){ printf '%b[FAIL]%b %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

trap 'die "Installation failed at line $LINENO."' ERR

clear
cat <<'NYX'
\033[36m
 _   _            ___          _ _                  _
| \ | |_   ___  _|_ _|___  ___| (_) ___  _ __ ___ | |__   ___
|  \| | | | \ \/ /| |/ __|/ __| | |/ _ \| '_ ` _ \| '_ \ / _ \\
| |\  | |_| |>  < | | (__| (__| | | (_) | | | | | | |_) |  __/
|_| \_|\__,_/_/\_\|___\___|\___|_|_|\___/|_| |_| |_|_.__/ \___|

       NYX ILLogical IMPULSE FOR INIT FREEDOM
       ARTIX LINUX • OPENRC • HYPRLAND • end-4
\033[0m
NYX
printf '\n'

[[ $EUID -ne 0 ]] || die 'Do not run this installer as root.'
command -v pacman >/dev/null 2>&1 || die 'pacman is required.'
command -v sudo >/dev/null 2>&1 || die 'sudo is required.'
command -v git >/dev/null 2>&1 || die 'git is required.'
command -v makepkg >/dev/null 2>&1 || die 'makepkg is required.'

# Confirm Artix without assuming a particular init implementation.
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
else
    die '/etc/os-release not found.'
fi
[[ "${ID:-}" == 'artix' || "${ID_LIKE:-}" == *artix* ]] || die 'This installer is for Artix Linux.'

# Make sudo usable and fail early if credentials are wrong.
sudo -v

choice(){
    local prompt="$1" default="$2" answer
    read -rp "$prompt [$default]: " answer
    printf '%s' "${answer:-$default}"
}
confirm(){
    local prompt="$1" default="${2:-N}" answer
    read -rp "$prompt [$default/y]: " answer
    answer="${answer:-$default}"
    [[ "${answer,,}" == 'y' || "${answer,,}" == 'yes' ]]
}

info 'Checking the current upstream end-4 tree...'
mkdir -p "$CACHE_DIR"
if [[ -d "$DOTS_DIR/.git" ]]; then
    git -C "$DOTS_DIR" fetch --depth=1 origin "$BRANCH"
    git -C "$DOTS_DIR" reset --hard "origin/$BRANCH"
else
    rm -rf "$DOTS_DIR"
    git clone --depth=1 --branch "$BRANCH" "$REPO" "$DOTS_DIR"
fi

UPSTREAM_REV="$(git -C "$DOTS_DIR" rev-parse --short HEAD)"
ok "Using end-4 revision $UPSTREAM_REV."

# ============================================================
# OPTIONS
# ============================================================

audio='y'
bluetooth='y'
fonts='y'
screenshot='y'
filemanager='y'
python='y'
microtex='y'
firmware='n'

if ! confirm 'Install the full end-4 dependency set?' 'Y'; then
    warn 'Minimal mode selected; a few optional upstream components will be skipped.'
    audio='n'
    bluetooth='n'
    screenshot='n'
    microtex='n'
fi

if confirm 'Install/update SDDM OpenRC integration?' 'Y'; then
    sddm='y'
else
    sddm='n'
fi

if confirm 'Enable UFW with deny-incoming / allow-outgoing defaults?' 'N'; then
    ufw='y'
else
    ufw='n'
fi

if confirm 'Enable laptop services (acpid, upower, fwupd when available)?' 'Y'; then
    power='y'
else
    power='n'
fi

printf '\n'
printf 'Repository : %s\n' "$REPO"
printf 'Revision   : %s\n' "$UPSTREAM_REV"
printf 'Init       : OpenRC\n'
printf 'Home       : %s\n' "$HOME"
printf 'Quickshell : %s\n' "$VENV_DIR"
printf '\n'
confirm 'Proceed with Artix end-4 installation?' 'Y' || exit 0

# ============================================================
# BASE PACKAGE LAYER
# ============================================================

info 'Refreshing repositories...'
sudo pacman -Syu --needed --noconfirm

BASE_PKGS=(
    base-devel git rsync curl wget jq ripgrep bc cmake clang
    coreutils fontconfig xdg-user-dirs
    hyprland xorg-xwayland wl-clipboard
    qt6-base qt6-declarative qt6-wayland qt6-tools qt6-svg qt6-multimedia
    qt6-5compat qt6-imageformats qt6-positioning qt6-sensors qt6-virtualkeyboard
    kirigami kdialog syntax-highlighting
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    networkmanager
    elogind dbus polkit seatd
    gnome-keyring polkit-kde-agent
    fish kitty fuzzel eza starship
    imagemagick matugen
    tesseract tesseract-data-eng
    upower brightnessctl ddcutil
    hyprsunset hypridle hyprlock hyprpicker
    hyprshot slurp swappy wf-recorder
    wlogout playerctl cliphist
    pavucontrol-qt libdbusmenu-gtk3
    wtype ydotool
    libqalculate
)

if [[ "$audio" == y ]]; then
    BASE_PKGS+=(pipewire-pulse wireplumber cava)
fi

if [[ "$bluetooth" == y ]]; then
    BASE_PKGS+=(bluez bluez-utils blueman bluedevil)
fi

if [[ "$fonts" == y ]]; then
    BASE_PKGS+=(
        adw-gtk-theme breeze
        darkly-bin
        otf-space-grotesk
        ttf-jetbrains-mono-nerd
        ttf-material-symbols-variable-git
        ttf-readex-pro
        ttf-rubik-vf
        ttf-twemoji
    )
fi

if [[ "$screenshot" != y ]]; then
    BASE_PKGS+=(grim)
fi

if [[ "$filemanager" == y ]]; then
    BASE_PKGS+=(dolphin systemsettings)
fi

if [[ "$python" == y ]]; then
    BASE_PKGS+=(uv python)
fi

if [[ "$microtex" == y ]]; then
    BASE_PKGS+=(ninja)
fi

if [[ "$power" == y ]]; then
    BASE_PKGS+=(acpi lm_sensors nvme-cli smartmontools fwupd)
fi

if [[ "$sddm" == y ]]; then
    BASE_PKGS+=(sddm)
fi

if [[ "$ufw" == y ]]; then
    BASE_PKGS+=(ufw)
fi

# Package availability differs slightly between Artix mirrors/releases.
# Install everything resolvable from the native repositories first.
AVAILABLE_PKGS=()
MISSING_PKGS=()
for pkg in "${BASE_PKGS[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        AVAILABLE_PKGS+=("$pkg")
    else
        MISSING_PKGS+=("$pkg")
    fi
done

info "Installing ${#AVAILABLE_PKGS[@]} native packages..."
sudo pacman -S --needed --noconfirm "${AVAILABLE_PKGS[@]}"

if ((${#MISSING_PKGS[@]})); then
    warn 'The following packages were not found in enabled Artix repositories:'
    printf '  %s\n' "${MISSING_PKGS[@]}"
    warn 'They will be attempted through the AUR helper.'
fi

# ============================================================
# AUR HELPER
# ============================================================

if ! command -v yay >/dev/null 2>&1; then
    info 'Installing yay from the AUR because end-4 uses several Arch/AUR packages.'
    YAY_BUILD="$(mktemp -d)"
    trap 'rm -rf "$YAY_BUILD"' EXIT
    git clone --depth=1 https://aur.archlinux.org/yay.git "$YAY_BUILD/yay"
    chown -R "$USER:$USER" "$YAY_BUILD"
    (cd "$YAY_BUILD/yay" && makepkg -si --noconfirm)
    rm -rf "$YAY_BUILD"
    trap 'die "Installation failed at line $LINENO."' ERR
fi

# Install packages missing from Artix repos from AUR.
if ((${#MISSING_PKGS[@]})); then
    info 'Resolving missing dependencies through AUR...'
    yay -S --needed --noconfirm "${MISSING_PKGS[@]}"
fi

# A few current end-4 names are AUR packages even when not missing above.
AUR_PKGS=(
    breeze-plus
    go-yq
    matugen-bin
    adw-gtk-theme
    darkly-bin
    otf-space-grotesk
    ttf-material-symbols-variable-git
    ttf-readex-pro
    ttf-rubik-vf
    ttf-twemoji
    songrec
    translate-shell
)
info 'Resolving end-4 AUR dependencies...'
yay -S --needed --noconfirm "${AUR_PKGS[@]}" || warn 'Some non-critical AUR packages could not be installed; the installer will continue.'

# ============================================================
# BUILD UPSTREAM LOCAL PKGBUILDS
# ============================================================

build_local_pkg(){
    local name="$1" dir="$DOTS_DIR/sdata/dist-arch/$1"
    [[ -d "$dir" && -f "$dir/PKGBUILD" ]] || {
        warn "Upstream local package $name is not present; skipping."
        return 0
    }
    info "Building upstream local package: $name"
    rm -f "$dir"/*.pkg.tar.* "$dir"/*.src.tar.* 2>/dev/null || true
    chown -R "$USER:$USER" "$dir"
    (cd "$dir" && makepkg -si --needed --noconfirm)
}

# Build actual end-4 packages first, then the meta packages.
for pkg in \
    illogical-impulse-bibata-modern-classic-bin \
    illogical-impulse-microtex-git \
    illogical-impulse-quickshell-git
    do build_local_pkg "$pkg"; done

for pkg in \
    illogical-impulse-audio \
    illogical-impulse-backlight \
    illogical-impulse-basic \
    illogical-impulse-fonts-themes \
    illogical-impulse-hyprland \
    illogical-impulse-kde \
    illogical-impulse-portal \
    illogical-impulse-python \
    illogical-impulse-screencapture \
    illogical-impulse-toolkit \
    illogical-impulse-widgets
    do build_local_pkg "$pkg"; done

# ============================================================
# OPENRC SETUP
# ============================================================

info 'Configuring OpenRC services...'

rc_add(){
    sudo rc-update add "$1" "$2" >/dev/null 2>&1 || true
}

rc_add dbus default
rc_add elogind boot
rc_add NetworkManager default

if [[ "$bluetooth" == y ]]; then
    rc_add bluetooth default
fi

if [[ "$power" == y ]]; then
    rc_add acpid default
    rc_add fwupd default
fi

if [[ "$sddm" == y ]]; then
    # Artix provides the OpenRC companion package on supported repos.
    if pacman -Si sddm-openrc >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm sddm-openrc
        rc_add sddm default
    else
        warn 'sddm-openrc is unavailable; SDDM was installed but not registered with OpenRC.'
    fi
fi

# seatd is deliberately not the session manager.  Upstream's non-Arch
# notes recommend elogind for XDG_RUNTIME_DIR/session semantics.
if id -nG | tr ' ' '\n' | grep -qx seat; then :; else sudo usermod -aG seat "$USER" || true; fi

# ============================================================
# IWD / NETWORKMANAGER
# ============================================================

if pacman -Q iwd >/dev/null 2>&1; then
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/20-iwd.conf >/dev/null <<'EOF2'
[device]
wifi.backend=iwd
EOF2
    sudo mkdir -p /etc/iwd
    sudo tee /etc/iwd/main.conf >/dev/null <<'EOF2'
[General]
EnableNetworkConfiguration=false
EOF2
    rc_add iwd default
fi

# ============================================================
# YDOTOOL — OPENRC COMPATIBILITY
# ============================================================

info 'Configuring ydotoold for OpenRC...'

sudo groupadd -f input
sudo usermod -aG input "$USER" || true

sudo tee /etc/udev/rules.d/70-uinput-ydotool.rules >/dev/null <<'EOF2'
KERNEL=="uinput", GROUP="input", MODE="0660", TAG+="uaccess"
EOF2

sudo mkdir -p /etc/init.d
sudo tee /etc/init.d/ydotoold >/dev/null <<'EOF2'
#!/sbin/openrc-run

name="ydotoold"
description="ydotool daemon for end-4 on OpenRC"
command="/usr/bin/ydotoold"
command_args="--socket-path=/run/ydotoold/socket --socket-own=__UID__:__GID__ --socket-perm=0600"
command_background="yes"
pidfile="/run/ydotoold.pid"
output_log="/var/log/ydotoold.log"
error_log="/var/log/ydotoold.log"

depend() {
    need localmount
    after udev
}

start_pre() {
    checkpath --directory --mode 0755 /run/ydotoold
    rm -f /run/ydotoold/socket
    chown root:root /run/ydotoold
}
EOF2

UID_NOW="$(id -u)"
GID_NOW="$(id -g)"
sudo sed -i \
    -e "s/__UID__/${UID_NOW}/g" \
    -e "s/__GID__/${GID_NOW}/g" \
    /etc/init.d/ydotoold
sudo chmod +x /etc/init.d/ydotoold
rc_add ydotoold default

# ============================================================
# UFW
# ============================================================

if [[ "$ufw" == y ]] && command -v ufw >/dev/null 2>&1; then
    info 'Configuring UFW...'
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw --force enable
fi

# ============================================================
# ENVIRONMENT
# ============================================================

mkdir -p "$HOME/.config/environment.d"
cat > "$HOME/.config/environment.d/10-end4-artix.conf" <<'EOF2'
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=wayland
EOF2

cat > "$HOME/.config/environment.d/20-end4-ydotool.conf" <<'EOF2'
YDOTOOL_SOCKET=/run/ydotoold/socket
EOF2

# ============================================================
# PYTHON ENVIRONMENT
# ============================================================

if [[ "$python" == y ]]; then
    info 'Creating the Quickshell Python virtual environment...'
    mkdir -p "$(dirname "$VENV_DIR")"
    uv venv --prompt .venv "$VENV_DIR" -p 3.13 || uv venv --prompt .venv "$VENV_DIR"

    if [[ -f "$DOTS_DIR/sdata/uv/requirements.in" ]]; then
        uv pip install --python "$VENV_DIR/bin/python" -r "$DOTS_DIR/sdata/uv/requirements.in"
    elif [[ -f "$DOTS_DIR/sdata/uv/requirements.txt" ]]; then
        uv pip install --python "$VENV_DIR/bin/python" -r "$DOTS_DIR/sdata/uv/requirements.txt"
    else
        warn 'No upstream Python requirements file found; the venv was created but no packages were added.'
    fi
fi

# ============================================================
# COPY DOTS
# ============================================================

info 'Backing up existing end-4 targets...'
BACKUP_DIR="$HOME/.local/state/nyx-end4-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [[ -d "$HOME/.config/hypr" ]]; then
    cp -a "$HOME/.config/hypr" "$BACKUP_DIR/"
fi
if [[ -d "$HOME/.config/quickshell" ]]; then
    cp -a "$HOME/.config/quickshell" "$BACKUP_DIR/"
fi

info 'Copying upstream end-4 configuration...'
mkdir -p "$HOME/.config" "$HOME/.local"

if [[ -d "$DOTS_DIR/dots/.config" ]]; then
    rsync -a --delete \
        "$DOTS_DIR/dots/.config/" \
        "$HOME/.config/"
fi

if [[ -d "$DOTS_DIR/dots/.local" ]]; then
    rsync -a --delete \
        "$DOTS_DIR/dots/.local/" \
        "$HOME/.local/"
fi

# ============================================================
# ARTIX / OPENRC PATCHES TO USER CONFIG
# ============================================================

info 'Applying OpenRC/session compatibility patches...'

# end-4 currently uses loginctl for session lock and also has a fallback
# systemctl suspend.  elogind provides the loginctl implementation on Artix.
while IFS= read -r -d '' file; do
    sed -i \
        -e 's/systemctl suspend || loginctl suspend/loginctl suspend/g' \
        -e 's/systemctl suspend/loginctl suspend/g' \
        -e 's/systemctl hibernate/loginctl hibernate/g' \
        -e 's/systemctl reboot/loginctl reboot/g' \
        -e 's/systemctl poweroff/loginctl poweroff/g' \
        "$file"
done < <(find "$HOME/.config/hypr" "$HOME/.config/quickshell" -type f \( -name '*.conf' -o -name '*.sh' -o -name '*.qml' \) -print0 2>/dev/null)

# Ensure the env file explicitly carries the ydotool socket into Hyprland.
mkdir -p "$HOME/.config/hypr/custom"
cat > "$HOME/.config/hypr/custom/env.conf" <<'EOF2'
$env = YDOTOOL_SOCKET,/run/ydotoold/socket
env = YDOTOOL_SOCKET,/run/ydotoold/socket
EOF2

# Ensure the daemon is started before Hyprland starts using it.
cat > "$HOME/.config/hypr/custom/execs.conf" <<'EOF2'
exec-once = sh -c 'while [ ! -S /run/ydotoold/socket ]; do sleep 0.25; done'
EOF2

# Upstream currently expects the quickshell venv through this variable.
mkdir -p "$HOME/.config/environment.d"
cat > "$HOME/.config/environment.d/30-end4-venv.conf" <<EOF2
ILLOGICAL_IMPULSE_VIRTUAL_ENV=$VENV_DIR
EOF2

# Use fish as the default shell if it exists (end-4's own config expects fish).
if command -v fish >/dev/null 2>&1; then
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]]; then
        chsh -s "$(command -v fish)"
    fi
fi

# ============================================================
# PERMISSIONS / FONT CACHE / CHECKS
# ============================================================

chmod +x "$HOME/.config/hypr"/**/*.sh 2>/dev/null || true
find "$HOME/.config" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true
xdg-user-dirs-update >/dev/null 2>&1 || true

if command -v systemctl >/dev/null 2>&1; then
    warn 'systemctl is present on this machine; this installer does not use it.'
fi

# ============================================================
# FINAL DIAGNOSTICS
# ============================================================

info 'Running end-4 diagnostics...'

printf '\n--- OpenRC ---\n'
rc-status --all 2>/dev/null || true

printf '\n--- Elogind ---\n'
if command -v loginctl >/dev/null 2>&1; then
    loginctl show-session "$(loginctl | awk -v u="$USER" '$0 ~ u {print $1; exit}')" -p Type -p Remote 2>/dev/null || true
fi

printf '\n--- Hyprland ---\n'
Hyprland --version 2>/dev/null || true

printf '\n--- Quickshell ---\n'
command -v qs >/dev/null 2>&1 && qs --version 2>/dev/null || true

printf '\n--- Python environment ---\n'
if [[ -x "$VENV_DIR/bin/python" ]]; then
    "$VENV_DIR/bin/python" --version
fi

printf '\n--- Remaining systemctl references in configs ---\n'
rg -n --hidden --glob '!cache' 'systemctl' "$HOME/.config/hypr" "$HOME/.config/quickshell" 2>/dev/null || true

printf '\n%b============================================================%b\n' "$C_GREEN" "$C_RESET"
printf '%b  NYX ILLogical IMPULSE FOR INIT FREEDOM — COMPLETE%b\n' "$C_GREEN" "$C_RESET"
printf '  Upstream revision : %s\n' "$UPSTREAM_REV"
printf '  Init system       : OpenRC\n'
printf '  Session manager   : elogind\n'
printf '  Config source     : %s\n' "$REPO"
printf '  Backup            : %s\n' "$BACKUP_DIR"
printf '%b============================================================%b\n' "$C_GREEN" "$C_RESET"
printf '\nLog out and back in before launching Hyprland so the new groups and environment are active.\n'
