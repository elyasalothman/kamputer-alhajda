# shellcheck shell=bash
# إعدادات بناء نظام «الهجدة» — Alhajda OS build configuration.
# Sourced by every build script. Override any value through the environment.

: "${ALHAJDA_VERSION:=1.1.0}"
: "${UBUNTU_SUITE:=noble}"                 # Ubuntu 24.04 LTS
: "${UBUNTU_MIRROR:=http://archive.ubuntu.com/ubuntu}"
: "${WORK:=/mnt/alhajda-work}"              # big scratch dir (GitHub runners: /mnt)
: "${OUT:=${WORK}/out}"                     # final images land here
: "${DISK_SIZE:=16G}"                       # virtual disk size (grows on first boot)
: "${BOTTLES_PREINSTALL:=false}"            # true = bake Bottles (flatpak) into the image (+~1.5 GB)

CHROOT="${WORK}/chroot"
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_BASENAME="alhajda-${ALHAJDA_VERSION}"

export ALHAJDA_VERSION UBUNTU_SUITE UBUNTU_MIRROR WORK OUT DISK_SIZE BOTTLES_PREINSTALL \
       CHROOT OS_DIR IMAGE_BASENAME

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
