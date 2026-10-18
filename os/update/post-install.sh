#!/bin/bash
# Runs as root on the user's machine after alhajda-update copied overlay/ into / .
# Re-applies Alhajda branding and enables the units that ship in the overlay.
# Never touches partitions or /home. Env: BUNDLE_DIR, ALHAJDA_NEW_VERSION, ALHAJDA_OLD_VERSION, ALHAJDA_ROOT (tests).
set -uo pipefail
R="${ALHAJDA_ROOT:-}"
VER="${ALHAJDA_NEW_VERSION:?}"
B="$R/usr/share/alhajda/branding"
log() { echo "[post-install] $*"; }

# --- branding images (SVG sources live in the bundle overlay) ---
if command -v rsvg-convert >/dev/null && [ -f "$B/wallpaper.svg" ]; then
  mkdir -p "$R/usr/share/backgrounds/alhajda" "$R/usr/share/alhajda/icons" "$R/usr/share/pixmaps"
  rsvg-convert -w 1920 -h 1080 "$B/wallpaper.svg" -o "$R/usr/share/backgrounds/alhajda/alhajda-wallpaper.png" || true
  rsvg-convert -w 256 -h 256 "$B/icon.svg" -o "$R/usr/share/alhajda/icons/alhajda.png" || true
  cp -f "$R/usr/share/alhajda/icons/alhajda.png" "$R/usr/share/pixmaps/alhajda.png" 2>/dev/null || true
  rsvg-convert -w 360 -h 120 "$B/logo-text.svg" -o "$R/usr/share/alhajda/icons/alhajda-logo.png" || true
fi
WP="$R/usr/share/backgrounds/alhajda/alhajda-wallpaper.png"
if [ -z "$R" ] && [ -f "$WP" ]; then
  # wallpapers that the image build replaced (local dpkg diversions)
  dpkg-divert --list 2>/dev/null | awk '/^local diversion of/ {print $4}' \
    | grep -iE 'backdrop|background|wallpaper' | while read -r img; do
        [ -e "$img" ] && cp -f "$WP" "$img"
      done
  W=/usr/share/plymouth/themes/spinner/watermark.png
  [ -e "$W" ] && cp -f /usr/share/alhajda/icons/alhajda-logo.png "$W"
fi

# --- identity: os-release / lsb-release / issue ---
if [ -f "$B/os-release" ]; then
  mkdir -p "$R/usr/lib" "$R/etc"
  sed "s/@VERSION@/${VER}/g" "$B/os-release" > "$R/usr/lib/os-release"
  sed "s/@VERSION@/${VER}/g" "$B/lsb-release" > "$R/etc/lsb-release"
  printf 'Alhajda %s (Ubuntu 24.04 LTS) \\n \\l\n\n' "${VER}" > "$R/etc/issue"
  printf 'Alhajda %s (Ubuntu 24.04 LTS)\n' "${VER}" > "$R/etc/issue.net"
fi
if [ -f "$B/firefox-policies.json" ]; then
  for d in "$R/etc/firefox/policies" "$R/usr/lib/firefox/distribution"; do
    [ -d "$d" ] && cp -f "$B/firefox-policies.json" "$d/policies.json"
  done
fi
mkdir -p "$R/etc/alhajda"
echo "$VER" > "$R/etc/alhajda/version"
# desktop shortcuts on users' desktops are re-synced by alhajda-firstlogin at next login
echo "$VER" > "$R/usr/share/alhajda/desktop-version"

[ -n "$R" ] && { log "test root: skipping systemd/apt"; exit 0; }

# --- packages that older images (1.0.0) may lack: best effort, online only ---
missing=()
for p in unattended-upgrades libnotify-bin python3; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
  log "installing: ${missing[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${missing[@]}" || log "WARN: apt install failed"
fi

# --- wired network: 1.0.0 left ethernet unmanaged; the overlay now fixes that ---
if command -v nmcli >/dev/null && nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^ethernet:unmanaged'; then
  log "restarting NetworkManager to manage ethernet"
  systemctl try-restart NetworkManager.service || true
fi

# --- units ---
systemctl daemon-reload || true
systemctl enable alhajda-update.timer 2>/dev/null || true
if ! grep -qw 'boot=casper' /proc/cmdline 2>/dev/null; then systemctl start alhajda-update.timer 2>/dev/null || true; fi
systemctl enable apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service 2>/dev/null || true
command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications 2>/dev/null || true
log "done (${ALHAJDA_OLD_VERSION:-?} -> ${VER})"
exit 0
