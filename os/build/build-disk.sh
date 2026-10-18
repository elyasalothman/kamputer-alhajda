#!/usr/bin/env bash
# Build an installed-system virtual disk (GPT: BIOS boot + EFI + ext4 root) from the rootfs,
# bootable with BIOS and UEFI, then convert it to VHDX (Hyper-V), VMDK (VirtualBox), qcow2.
# Usage: sudo -E os/build/build-disk.sh
set -euo pipefail
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"
[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }

RAW="${WORK}/${IMAGE_BASENAME}.raw"
MNT="${WORK}/disk-mnt"
mkdir -p "${OUT}" "${MNT}"

LOOP=""
cleanup() {
  for m in boot/efi dev/pts dev proc sys run; do
    mountpoint -q "${MNT}/${m}" && umount -lf "${MNT}/${m}" || true
  done
  mountpoint -q "${MNT}" && umount -lf "${MNT}" || true
  [ -n "${LOOP}" ] && losetup -d "${LOOP}" 2>/dev/null || true
}
trap cleanup EXIT

log "create ${DISK_SIZE} raw disk"
rm -f "${RAW}"
truncate -s "${DISK_SIZE}" "${RAW}"
sgdisk -Z "${RAW}"
sgdisk -n1:2048:+1M   -t1:EF02 -c1:"BIOS boot" \
       -n2:0:+512M    -t2:EF00 -c2:"EFI System" \
       -n3:0:0        -t3:8304 -c3:"alhajda-root" "${RAW}"
LOOP=$(losetup --find --show --partscan "${RAW}")
udevadm settle || true
sleep 1
mkfs.vfat -F 32 -n ALHAJDA-EFI "${LOOP}p2"
mkfs.ext4 -F -L alhajda-root "${LOOP}p3"

mount "${LOOP}p3" "${MNT}"
log "copy rootfs"
rsync -aHAX --numeric-ids \
  --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/run/*' --exclude='/tmp/*' \
  "${CHROOT}/" "${MNT}/"
mkdir -p "${MNT}/boot/efi"
mount "${LOOP}p2" "${MNT}/boot/efi"
for m in dev dev/pts proc sys; do mount --bind "/${m}" "${MNT}/${m}"; done
mount -t tmpfs tmpfs "${MNT}/run"

ROOT_UUID=$(blkid -s UUID -o value "${LOOP}p3")
EFI_UUID=$(blkid -s UUID -o value "${LOOP}p2")
cat > "${MNT}/etc/fstab" <<EOF
# Alhajda virtual disk
UUID=${ROOT_UUID}  /          ext4  errors=remount-ro  0 1
UUID=${EFI_UUID}   /boot/efi  vfat  umask=0077         0 1
EOF

log "user, autologin, bootloader"
chroot "${MNT}" /bin/bash -euxo pipefail <<CHROOT
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
groups=\$(for g in sudo adm cdrom dip plugdev lpadmin netdev audio video users; do getent group \$g >/dev/null && printf '%s,' \$g; done)
useradd -m -s /bin/bash -c "Alhajda" -G "\${groups%,}" alhajda
echo 'alhajda:alhajda' | chpasswd
mkdir -p /etc/lightdm/lightdm.conf.d
SESSION=xubuntu; [ -e /usr/share/xsessions/xubuntu.desktop ] || SESSION=xfce
cat > /etc/lightdm/lightdm.conf.d/50-alhajda-autologin.conf <<EOF
[Seat:*]
autologin-user=alhajda
autologin-user-timeout=0
autologin-session=\$SESSION
user-session=\$SESSION
EOF
echo alhajda > /etc/hostname
# BIOS
grub-install --target=i386-pc --recheck "${LOOP}"
# UEFI (signed shim+grub): fallback path \EFI\BOOT\BOOTX64.EFI and \EFI\ubuntu
grub-install --target=x86_64-efi --efi-directory=/boot/efi --uefi-secure-boot --removable --no-nvram
grub-install --target=x86_64-efi --efi-directory=/boot/efi --uefi-secure-boot --bootloader-id=ubuntu --no-nvram
update-grub
ls -R /boot/efi/EFI
CHROOT

sync
cleanup
trap - EXIT

log "convert images"
qemu-img convert -p -f raw -O vhdx -o subformat=dynamic "${RAW}" "${OUT}/${IMAGE_BASENAME}-hyperv.vhdx"
qemu-img convert -p -f raw -O vmdk -o subformat=streamOptimized "${RAW}" "${OUT}/${IMAGE_BASENAME}-virtualbox.vmdk"
qemu-img convert -p -f raw -O qcow2 -c "${RAW}" "${OUT}/${IMAGE_BASENAME}.qcow2"
ls -lh "${OUT}"
