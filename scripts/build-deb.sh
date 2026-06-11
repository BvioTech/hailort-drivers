#!/usr/bin/env bash
# Build hailo-pci_<version>_arm64.deb using dpkg-deb.
#
# Requirements:
#   - make + gcc (arm64 native)
#   - KERNEL_DIR: path to Rockchip 6.1.99 kernel headers
#
# Output: ./dist/hailo-pci_4.23.0_arm64.deb
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_VER="6.1.99"

: "${KERNEL_DIR:?KERNEL_DIR must point to the kernel headers directory}"

VERSION=$(grep -m1 "^Version:" "$REPO_ROOT/debian/control" | awk '{print $2}')
PKG_DIR="$REPO_ROOT/build/hailo-pci_${VERSION}_arm64"

echo "Building hailo-pci $VERSION (kernel $KERNEL_VER) ..."

rm -rf "$REPO_ROOT/build" "$REPO_ROOT/dist"
mkdir -p "$REPO_ROOT/dist" \
  "$PKG_DIR/DEBIAN" \
  "$PKG_DIR/lib/modules/$KERNEL_VER/kernel/drivers/misc" \
  "$PKG_DIR/lib/firmware/hailo" \
  "$PKG_DIR/etc/udev/rules.d" \
  "$PKG_DIR/etc/modprobe.d" \
  "$PKG_DIR/etc/modules-load.d"

# ── Kernel module ──────────────────────────────────────────────────────────
cd "$REPO_ROOT/linux/pcie"
make all KERNEL_DIR="$KERNEL_DIR" kernelver="$KERNEL_VER"
cp hailo_pci.ko "$PKG_DIR/lib/modules/$KERNEL_VER/kernel/drivers/misc/"
make clean KERNEL_DIR="$KERNEL_DIR"

# ── Firmware ───────────────────────────────────────────────────────────────
DRIVER_VERSION=$(grep -E "^#define HAILO_DRV_VER_(MAJOR|MINOR|REVISION)" \
  "$REPO_ROOT/common/hailo_ioctl_common.h" | awk '{print $3}' | paste -sd'.')
echo "Downloading firmware $DRIVER_VERSION ..."
curl -fsSL \
  "https://hailo-hailort.s3.eu-west-2.amazonaws.com/Hailo8/${DRIVER_VERSION}/FW/hailo8_fw.${DRIVER_VERSION}.bin" \
  -o "$PKG_DIR/lib/firmware/hailo/hailo8_fw.bin"

# ── Config files ───────────────────────────────────────────────────────────
cp "$REPO_ROOT/linux/pcie/51-hailo-udev.rules"  "$PKG_DIR/etc/udev/rules.d/"
cp "$REPO_ROOT/linux/pcie/hailo_pci.conf"        "$PKG_DIR/etc/modprobe.d/"
cp "$REPO_ROOT/debian/hailo.conf"                "$PKG_DIR/etc/modules-load.d/"

# ── DEBIAN metadata ────────────────────────────────────────────────────────
cp "$REPO_ROOT/debian/control"  "$PKG_DIR/DEBIAN/"
cp "$REPO_ROOT/debian/postinst" "$PKG_DIR/DEBIAN/"
cp "$REPO_ROOT/debian/prerm"    "$PKG_DIR/DEBIAN/"
cp "$REPO_ROOT/debian/postrm"   "$PKG_DIR/DEBIAN/"
chmod 755 "$PKG_DIR/DEBIAN/postinst" "$PKG_DIR/DEBIAN/prerm" "$PKG_DIR/DEBIAN/postrm"

# ── Package ────────────────────────────────────────────────────────────────
dpkg-deb --build "$PKG_DIR" "$REPO_ROOT/dist/hailo-pci_${VERSION}_arm64.deb"

echo ""
echo "Built: $REPO_ROOT/dist/hailo-pci_${VERSION}_arm64.deb"
ls -lh "$REPO_ROOT/dist/hailo-pci_${VERSION}_arm64.deb"
