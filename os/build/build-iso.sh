#!/usr/bin/env bash
# Build the hybrid (BIOS + UEFI) live ISO from the rootfs. Usage: sudo -E os/build/build-iso.sh
set -euo pipefail
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"
[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }

ISO_DIR="${WORK}/iso"
ISO_OUT="${OUT}/${IMAGE_BASENAME}-amd64.iso"
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/casper" "${ISO_DIR}/boot/grub" "${ISO_DIR}/.disk" "${OUT}"

KVER=$(ls -1 "${CHROOT}/lib/modules" | sort -V | tail -n1)
log "kernel ${KVER}"
cp "${CHROOT}/boot/vmlinuz-${KVER}" "${ISO_DIR}/casper/vmlinuz"
cp "${CHROOT}/boot/initrd.img-${KVER}" "${ISO_DIR}/casper/initrd"

chroot "${CHROOT}" dpkg-query -W --showformat='${Package} ${Version}\n' > "${ISO_DIR}/casper/filesystem.manifest"
du -sx --block-size=1 "${CHROOT}" | cut -f1 > "${ISO_DIR}/casper/filesystem.size"
echo "Alhajda ${ALHAJDA_VERSION} \"Noble\" - amd64 ($(date -u +%Y%m%d))" > "${ISO_DIR}/.disk/info"
touch "${ISO_DIR}/alhajda.marker"

log "mksquashfs (xz)"
mksquashfs "${CHROOT}" "${ISO_DIR}/casper/filesystem.squashfs" \
  -noappend -comp xz -Xbcj x86 -b 1M -processors "$(nproc)" -no-progress \
  -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*' 'boot/efi/*'

# checksums for casper-md5check ("Verify Live ISO checksums" at boot)
( cd "${ISO_DIR}" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt )

cat > "${ISO_DIR}/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
insmod all_video
insmod part_gpt
insmod part_msdos
insmod iso9660
search --no-floppy --set=root --file /alhajda.marker
serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial

menuentry "Alhajda Live (Arabic)" {
  linux /casper/vmlinuz boot=casper locale=ar_SA.UTF-8 quiet splash console=ttyS0,115200 console=tty0 ---
  initrd /casper/initrd
}
menuentry "Alhajda Live (English)" {
  linux /casper/vmlinuz boot=casper locale=en_US.UTF-8 quiet splash console=ttyS0,115200 console=tty0 ---
  initrd /casper/initrd
}
menuentry "Alhajda Live (safe graphics / nomodeset)" {
  linux /casper/vmlinuz boot=casper locale=ar_SA.UTF-8 nomodeset console=ttyS0,115200 console=tty0 ---
  initrd /casper/initrd
}
menuentry "Alhajda Live (load to RAM)" {
  linux /casper/vmlinuz boot=casper toram locale=ar_SA.UTF-8 quiet splash ---
  initrd /casper/initrd
}
EOF

log "grub-mkrescue -> ${ISO_OUT}"
grub-mkrescue -o "${ISO_OUT}" "${ISO_DIR}" -volid ALHAJDA
ls -lh "${ISO_OUT}"
rm -rf "${ISO_DIR}"
