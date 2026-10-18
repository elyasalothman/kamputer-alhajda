#!/usr/bin/env bash
# Build the small Alhajda overlay update bundle attached to every os-v* release:
#   ${OUT}/alhajda-update-<version>.tar.gz   = VERSION + post-install.sh + overlay/{etc,usr}
# Usage: os/update/build-update-bundle.sh [--selftest]
#   --selftest adds a marker file (/usr/share/alhajda/selftest-applied) used by the CI VM test.
set -euo pipefail
# shellcheck source=../build/config.sh
source "$(dirname "$0")/../build/config.sh"
SELFTEST=0; [ "${1:-}" = "--selftest" ] && SELFTEST=1
mkdir -p "${OUT}"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/overlay/usr/share/alhajda/branding"
rsync -a "${OS_DIR}/rootfs-overlay/" "$T/overlay/"
rsync -a "${OS_DIR}/branding/" "$T/overlay/usr/share/alhajda/branding/"
# never ship anything outside etc/ and usr/
for d in "$T/overlay"/*; do case "$(basename "$d")" in etc|usr) ;; *) echo "unexpected top-level dir in overlay: $d"; exit 1;; esac; done
install -m 0755 "${OS_DIR}/update/post-install.sh" "$T/post-install.sh"
echo "${ALHAJDA_VERSION}" > "$T/VERSION"
echo "${ALHAJDA_VERSION}" > "$T/overlay/usr/share/alhajda/desktop-version"
if [ "$SELFTEST" = 1 ]; then
  echo "selftest bundle ${ALHAJDA_VERSION}" > "$T/overlay/usr/share/alhajda/selftest-applied"
fi
F="${OUT}/alhajda-update-${ALHAJDA_VERSION}.tar.gz"
tar --owner=0 --group=0 --numeric-owner --sort=name -czf "$F" -C "$T" .
echo "bundle: $F ($(du -h "$F" | cut -f1))"
echo "entries: $(tar -tzf "$F" | wc -l)"
