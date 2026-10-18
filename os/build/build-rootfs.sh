#!/usr/bin/env bash
# Build the Alhajda root filesystem (Ubuntu 24.04 + XFCE + Arabic + Wine) with debootstrap.
# Usage: sudo -E os/build/build-rootfs.sh
set -euo pipefail
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"

[[ $EUID -eq 0 ]] || { echo "run as root (sudo -E)"; exit 1; }

cleanup() {
  for m in dev/pts dev proc sys run; do
    mountpoint -q "${CHROOT}/${m}" && umount -lf "${CHROOT}/${m}" || true
  done
}
trap cleanup EXIT

log "debootstrap ${UBUNTU_SUITE} -> ${CHROOT}"
rm -rf "${CHROOT}"
mkdir -p "${CHROOT}" "${OUT}"
# mirrors occasionally drop a package mid-download: retry a few times
# the last attempt falls back to the main Ubuntu archive in case the regional mirror is broken
for attempt in 1 2 3; do
  mirror="${UBUNTU_MIRROR}"; [ "$attempt" = 3 ] && mirror="http://archive.ubuntu.com/ubuntu"
  if debootstrap --arch=amd64 --components=main,restricted,universe,multiverse \
       "${UBUNTU_SUITE}" "${CHROOT}" "${mirror}"; then break; fi
  [ "$attempt" = 3 ] && { echo "debootstrap failed 3 times"; exit 1; }
  echo "debootstrap failed (attempt ${attempt}), retrying in 20s"; sleep 20
  rm -rf "${CHROOT}"; mkdir -p "${CHROOT}"
done

log "copy rootfs overlay + branding"
rsync -a "${OS_DIR}/rootfs-overlay/" "${CHROOT}/"
mkdir -p "${CHROOT}/usr/share/alhajda/branding"
rsync -a "${OS_DIR}/branding/" "${CHROOT}/usr/share/alhajda/branding/"
install -m 0755 "${OS_DIR}/build/chroot-setup.sh" "${CHROOT}/tmp/chroot-setup.sh"

log "mount pseudo filesystems"
mount --bind /dev "${CHROOT}/dev"
mount --bind /dev/pts "${CHROOT}/dev/pts"
mount -t proc proc "${CHROOT}/proc"
# /sys is deliberately NOT mounted: shim/grub postinst scripts would otherwise try to
# touch the build host's EFI variables.
mkdir -p "${CHROOT}/run"
mount -t tmpfs tmpfs "${CHROOT}/run"
cp /etc/resolv.conf "${CHROOT}/etc/resolv.conf.build" 2>/dev/null || true
rm -f "${CHROOT}/etc/resolv.conf"
cat /etc/resolv.conf > "${CHROOT}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${CHROOT}/etc/resolv.conf"

log "configure system inside chroot"
chroot "${CHROOT}" /usr/bin/env -i \
  HOME=/root PATH=/usr/sbin:/usr/bin:/sbin:/bin TERM=dumb \
  UBUNTU_MIRROR="${UBUNTU_MIRROR}" ALHAJDA_VERSION="${ALHAJDA_VERSION}" \
  BOTTLES_PREINSTALL="${BOTTLES_PREINSTALL}" \
  /bin/bash /tmp/chroot-setup.sh

rm -f "${CHROOT}/tmp/chroot-setup.sh" "${CHROOT}/etc/resolv.conf.build"
# systemd-resolved stub, as on a normal Ubuntu install
ln -sf ../run/systemd/resolve/stub-resolv.conf "${CHROOT}/etc/resolv.conf"

cleanup
trap - EXIT
log "rootfs size: $(du -sh --one-file-system "${CHROOT}" | cut -f1)"
