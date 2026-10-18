#!/usr/bin/env bash
# Compress / checksum / split the images for GitHub (Releases cap each asset at 2 GiB).
# Usage: os/build/package.sh   -> ${OUT}/release/
set -euo pipefail
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"
REL="${OUT}/release"
PART_SIZE="${PART_SIZE:-1900M}"
mkdir -p "${REL}"
cd "${OUT}"

# VHDX is zipped (Windows can unzip natively); VMDK (streamOptimized) and qcow2 (-c) and the
# ISO's squashfs are already compressed.
if [ -f "${IMAGE_BASENAME}-hyperv.vhdx" ]; then
  zip -1 -j "${REL}/${IMAGE_BASENAME}-hyperv.vhdx.zip" "${IMAGE_BASENAME}-hyperv.vhdx"
  rm -f "${IMAGE_BASENAME}-hyperv.vhdx"
fi
for f in "${IMAGE_BASENAME}-amd64.iso" "${IMAGE_BASENAME}-virtualbox.vmdk" "${IMAGE_BASENAME}.qcow2"; do
  [ -f "$f" ] && mv "$f" "${REL}/"
done

# small files: the overlay update bundle (read by alhajda-update inside the OS) and the
# Windows one-step installers (AlhajdaSetup.cmd / os.ps1 / install-alhajda-vm.ps1)
for f in "${OUT}"/alhajda-update-*.tar.gz; do [ -f "$f" ] && cp -f "$f" "${REL}/"; done
cp -f "${OS_DIR}/windows/AlhajdaSetup.cmd" "${OS_DIR}/windows/os.ps1" "${OS_DIR}/windows/install-alhajda-vm.ps1" "${REL}/"

cd "${REL}"
sha256sum ./*.iso ./*.zip ./*.vmdk ./*.qcow2 ./*.tar.gz ./*.cmd ./*.ps1 2>/dev/null | sed 's#\./##' > SHA256SUMS
cat SHA256SUMS
# split anything above PART_SIZE into name.part00, name.part01 ... (scripts re-join them)
for f in *.iso *.zip *.vmdk *.qcow2; do
  [ -f "$f" ] || continue
  if [ "$(stat -c %s "$f")" -gt $((1900*1024*1024)) ]; then
    split -b "${PART_SIZE}" -d -a 2 "$f" "${f}.part"
    rm -f "$f"
  fi
done
ls -l "${REL}"
