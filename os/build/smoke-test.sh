#!/usr/bin/env bash
# Headless QEMU boot smoke test. Boots an image, waits for ALHAJDA_BOOT_OK on the serial port,
# takes a screenshot of the desktop, then powers off.
# Usage: smoke-test.sh <name> <bios|uefi> <cdrom|disk> <image> [format] [timeout_s]
set -euo pipefail
NAME="$1" FW="$2" KIND="$3" IMG="$4" FMT="${5:-raw}" TIMEOUT="${6:-900}"
LOGDIR="${SMOKE_LOGDIR:-${WORK:-/tmp}/smoke}"
mkdir -p "${LOGDIR}"
SER="${LOGDIR}/${NAME}-serial.log"
MON="${LOGDIR}/${NAME}.mon"
: > "${SER}"

ACCEL=(-accel tcg)
if [ -w /dev/kvm ]; then ACCEL=(-enable-kvm -cpu host); fi
FWARGS=()
if [ "$FW" = "uefi" ]; then
  CODE="" VARS_SRC=""
  for f in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do [ -f "$f" ] && { CODE=$f; break; }; done
  for f in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do [ -f "$f" ] && { VARS_SRC=$f; break; }; done
  [ -n "$CODE" ] && [ -n "$VARS_SRC" ] || { echo "::error::OVMF firmware not found"; ls -l /usr/share/OVMF || true; exit 1; }
  cp "${VARS_SRC}" "${LOGDIR}/${NAME}-vars.fd"
  FWARGS=(-drive "if=pflash,format=raw,readonly=on,file=${CODE}" -drive "if=pflash,format=raw,file=${LOGDIR}/${NAME}-vars.fd")
fi
if [ "$KIND" = "cdrom" ]; then
  MEDIA=(-cdrom "${IMG}" -boot d)
else
  MEDIA=(-drive "file=${IMG},format=${FMT},if=virtio,snapshot=on")
fi

echo "[smoke:${NAME}] accel=${ACCEL[*]} fw=${FW} ${KIND} ${IMG}"
qemu-system-x86_64 "${ACCEL[@]}" -m 4096 -smp 2 -machine q35 \
  "${FWARGS[@]}" "${MEDIA[@]}" \
  -vga std -display none -serial "file:${SER}" \
  -monitor "unix:${MON},server,nowait" \
  -nic user,model=virtio-net-pci &
QPID=$!

ok=0
for ((t=0; t<TIMEOUT; t+=5)); do
  if grep -aq 'ALHAJDA_BOOT_OK' "${SER}"; then ok=1; break; fi
  if grep -aq 'ALHAJDA_BOOT_DEGRADED' "${SER}"; then break; fi
  kill -0 "${QPID}" 2>/dev/null || break
  sleep 5
done
echo "[smoke:${NAME}] waited ${t}s"

if [ -S "${MON}" ]; then
  [ "$ok" = 1 ] && sleep 25   # let the desktop draw
  echo "screendump ${LOGDIR}/${NAME}.ppm" | socat - "UNIX-CONNECT:${MON}" >/dev/null 2>&1 || true
  sleep 2
  [ -s "${LOGDIR}/${NAME}.ppm" ] && convert "${LOGDIR}/${NAME}.ppm" "${LOGDIR}/${NAME}.png" && rm -f "${LOGDIR}/${NAME}.ppm" || true
  echo "quit" | socat - "UNIX-CONNECT:${MON}" >/dev/null 2>&1 || true
fi
sleep 2; kill "${QPID}" 2>/dev/null || true; wait "${QPID}" 2>/dev/null || true

grep -a 'ALHAJDA_BOOT' "${SER}" || true
if [ "$ok" != 1 ]; then
  echo "::error::[smoke:${NAME}] no ALHAJDA_BOOT_OK within ${TIMEOUT}s — last serial lines:"
  tail -n 80 "${SER}" | tr -cd '\11\12\15\40-\176\200-\377'
  exit 1
fi
echo "[smoke:${NAME}] PASS"
