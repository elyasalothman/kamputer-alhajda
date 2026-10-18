#!/bin/bash
# Runs INSIDE the debootstrapped chroot. Installs packages and applies Alhajda branding.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 LANG=C.UTF-8
MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
VER="${ALHAJDA_VERSION:-1.0.0}"
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# never start services inside the build chroot
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

echo alhajda > /etc/hostname
printf '127.0.0.1\tlocalhost\n127.0.1.1\talhajda\n::1\tlocalhost ip6-localhost ip6-loopback\n' > /etc/hosts

printf 'Acquire::Retries "5";\n' > /etc/apt/apt.conf.d/80-alhajda-retries

# ---------- APT sources (deb822) ----------
: > /etc/apt/sources.list
cat > /etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb
URIs: ${MIRROR}
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
dpkg --add-architecture i386   # needed by wine32
apt-get update
apt-get "${APT_OPTS[@]}" install --no-install-recommends ca-certificates gnupg wget locales tzdata debconf-utils

# ---------- locale / time / keyboard ----------
sed -i 's/^# *\(ar_SA.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen || true
grep -q '^ar_SA.UTF-8' /etc/locale.gen || echo 'ar_SA.UTF-8 UTF-8' >> /etc/locale.gen
grep -q '^en_US.UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
cat > /etc/default/locale <<'EOF'
LANG=ar_SA.UTF-8
LANGUAGE=ar:en
EOF
ln -sf /usr/share/zoneinfo/Asia/Riyadh /etc/localtime
echo Asia/Riyadh > /etc/timezone
cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="ar,us"
XKBVARIANT=","
XKBOPTIONS="grp:alt_shift_toggle,grp_led:scroll"
BACKSPACE="guess"
EOF
cat <<'EOF' | debconf-set-selections
keyboard-configuration keyboard-configuration/layoutcode string ar,us
keyboard-configuration keyboard-configuration/xkb-keymap select ar
grub-pc grub-pc/install_devices_empty boolean true
grub-pc grub-pc/install_devices multiselect
grub-efi-amd64 grub2/update_nvram boolean false
shim-signed shim/enable_secureboot boolean false
lightdm shared/default-x-display-manager select lightdm
EOF

# ---------- Mozilla APT repo (real .deb Firefox, no snap) ----------
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/packages.mozilla.org.asc https://packages.mozilla.org/apt/repo-signing-key.gpg
cat > /etc/apt/sources.list.d/mozilla.sources <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
# (pins for snapd / firefox live in /etc/apt/preferences.d from the overlay)

apt-get update
apt-get "${APT_OPTS[@]}" dist-upgrade

# ---------- base system, kernel, boot ----------
apt-get "${APT_OPTS[@]}" install \
  linux-generic casper initramfs-tools \
  grub-pc grub-efi-amd64-bin grub-efi-amd64-signed shim-signed efibootmgr os-prober \
  systemd-resolved systemd-timesyncd network-manager sudo rsync less nano curl \
  cloud-guest-utils gdisk e2fsprogs dosfstools ntfs-3g squashfs-tools \
  plymouth plymouth-theme-spinner librsvg2-bin \
  keyboard-configuration console-setup \
  language-pack-ar language-pack-en language-pack-gnome-ar language-pack-gnome-en \
  fonts-noto-core fonts-noto-ui-core fonts-noto-mono fonts-noto-color-emoji fonts-dejavu-core \
  spice-vdagent

# ---------- light desktop: XFCE (Xubuntu core) ----------
apt-get "${APT_OPTS[@]}" install \
  xubuntu-core lightdm lightdm-gtk-greeter xfce4-terminal thunar mousepad ristretto \
  xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-xkb-plugin \
  network-manager-gnome gparted file-roller xdg-user-dirs-gtk

# ---------- browser ----------
apt-get "${APT_OPTS[@]}" install firefox firefox-l10n-ar

# ---------- Windows apps: Wine (+ Bottles via Flatpak) ----------
apt-get "${APT_OPTS[@]}" install --install-recommends wine wine64 wine32:i386 winetricks flatpak
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
if [ "${BOTTLES_PREINSTALL:-false}" = "true" ]; then
  flatpak install --system -y --noninteractive flathub com.usebottles.bottles \
    && mkdir -p /var/lib/alhajda && touch /var/lib/alhajda/bottles-installed \
    || echo "WARN: Bottles preinstall failed; first-boot service will retry"
fi

# make sure snapd never sneaks in
if dpkg -l snapd 2>/dev/null | grep -q '^ii'; then apt-get "${APT_OPTS[@]}" purge snapd; fi

# ---------- branding ----------
B=/usr/share/alhajda/branding
install -d /usr/share/backgrounds/alhajda /usr/share/alhajda/icons /usr/share/pixmaps
rsvg-convert -w 1920 -h 1080 "$B/wallpaper.svg" -o /usr/share/backgrounds/alhajda/alhajda-wallpaper.png
rsvg-convert -w 256 -h 256 "$B/icon.svg" -o /usr/share/alhajda/icons/alhajda.png
cp /usr/share/alhajda/icons/alhajda.png /usr/share/pixmaps/alhajda.png
rsvg-convert -w 360 -h 120 "$B/logo-text.svg" -o /usr/share/alhajda/icons/alhajda-logo.png

# os-release (diverted so base-files upgrades keep the Alhajda name)
dpkg-divert --local --rename --add /usr/lib/os-release
sed "s/@VERSION@/${VER}/g" "$B/os-release" > /usr/lib/os-release
ln -sf ../usr/lib/os-release /etc/os-release
sed "s/@VERSION@/${VER}/g" "$B/lsb-release" > /etc/lsb-release
printf 'Alhajda %s (Ubuntu 24.04 LTS) \\n \\l\n\n' "${VER}" > /etc/issue
printf 'Alhajda %s (Ubuntu 24.04 LTS)\n' "${VER}" > /etc/issue.net

# wallpaper: replace whatever image the XFCE/Xubuntu defaults point at
WP=/usr/share/backgrounds/alhajda/alhajda-wallpaper.png
for img in $(grep -rhoE '/usr/share/[^"<]+\.(png|jpg|jpeg|svg)' /etc/xdg 2>/dev/null \
             | grep -iE 'backdrop|background|wallpaper' | sort -u); do
  [ -e "$img" ] || continue
  dpkg-divert --local --rename --add "$img" || true
  cp "$WP" "$img"
done
for img in /usr/share/xfce4/backdrops/xubuntu-wallpaper.png /usr/share/backgrounds/xfce/xfce-verticals.png \
           /usr/share/backgrounds/xfce/xfce-shapes.svg; do
  if [ -e "$img" ] || [ -e "${img}.distrib" ]; then
    dpkg-divert --local --rename --add "$img" || true
    cp "$WP" "$img"
  fi
done

# boot splash: plymouth spinner with Alhajda watermark
if [ -d /usr/share/plymouth/themes/spinner ]; then
  W=/usr/share/plymouth/themes/spinner/watermark.png
  dpkg-divert --local --rename --add "$W" || true
  cp /usr/share/alhajda/icons/alhajda-logo.png "$W"
  if command -v plymouth-set-default-theme >/dev/null; then
    plymouth-set-default-theme spinner || true
  fi
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/spinner/spinner.plymouth 300 || true
  update-alternatives --set default.plymouth /usr/share/plymouth/themes/spinner/spinner.plymouth || true
fi

# Firefox policies: Alhajda homepage + bookmarks, Arabic UI
install -d /etc/firefox/policies /usr/lib/firefox/distribution
cp "$B/firefox-policies.json" /etc/firefox/policies/policies.json
cp "$B/firefox-policies.json" /usr/lib/firefox/distribution/policies.json

# initramfs: ntfs3 so casper can boot an ISO stored on a Windows (NTFS) partition
echo ntfs3 >> /etc/initramfs-tools/modules

# services
systemctl enable alhajda-bootcheck.service alhajda-growroot.service alhajda-bottles.service
systemctl enable NetworkManager.service systemd-resolved.service || true
systemctl set-default graphical.target

# default browser for XFCE
update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true

update-initramfs -u -k all

# ---------- cleanup ----------
apt-get -y autoremove --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
rm -f /usr/sbin/policy-rc.d
echo "chroot-setup done"
