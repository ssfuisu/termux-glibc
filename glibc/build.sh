#!/bin/bash
# Build glibc sysroot for Android, without proot.
# Usage: build.sh [aarch64|arm]
# Runs in GitHub Actions (Ubuntu 22.04). No local build required.
set -euo pipefail

ARCH="${1:-aarch64}"
GLIBC_VERSION="$(cat "$(dirname "$0")/version.txt" | tr -d ' \n')"
WORKDIR="${WORKDIR:-/tmp/glibc-build}"
SYSROOT="${SYSROOT:-/tmp/glibc-sysroot}"
PREFIX_ON_DEVICE="/data/data/com.termux.glibc/files/usr/glibc"

echo "Building glibc $GLIBC_VERSION for $ARCH"

sudo apt-get update
sudo apt-get install -y build-essential gawk bison python3 texinfo gettext \
  crossbuild-essential-arm64 crossbuild-essential-armhf patchelf curl xz-utils

mkdir -p "$WORKDIR" "$SYSROOT"
cd "$WORKDIR"

if [ ! -d "glibc-$GLIBC_VERSION" ]; then
  curl -fL "https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.xz" -o "glibc.tar.xz"
  tar -xf glibc.tar.xz
fi

if [ "$ARCH" = "aarch64" ]; then
  HOST="aarch64-linux-gnu"
  CC="aarch64-linux-gnu-gcc"
  DYNAMIC_LINKER="$PREFIX_ON_DEVICE/lib/ld-linux-aarch64.so.1"
else
  HOST="arm-linux-gnueabihf"
  CC="arm-linux-gnueabihf-gcc"
  DYNAMIC_LINKER="$PREFIX_ON_DEVICE/lib/ld-linux-armhf.so.3"
fi

# Android kernel compatibility: disable features missing on older kernels.
# clone3 and openat2 exist on newer kernels but must degrade gracefully.
mkdir -p "build-$ARCH"
cd "build-$ARCH"

echo "Configuring glibc..."
CC="$CC" \
"../glibc-$GLIBC_VERSION/configure" \
  --host="$HOST" \
  --prefix="/usr" \
  --with-headers="/usr/$HOST/include" \
  --disable-werror \
  --enable-kernel=4.9 \
  --without-selinux \
  --without-gd \
  libc_cv_ssp_strong=no \
  libc_cv_slibdir='/lib'

echo "Compiling..."
make -j"$(nproc)"
echo "Installing to sysroot..."
make install_root="$SYSROOT" install

echo "Rewriting interpreter to on-device path..."
find "$SYSROOT" -type f -executable -print0 | while IFS= read -r -d '' f; do
  if patchelf --print-interpreter "$f" >/dev/null 2>&1; then
    patchelf --set-interpreter "$DYNAMIC_LINKER" "$f" || true
  fi
done

echo "Sysroot ready: $SYSROOT"
ls -lh "$SYSROOT/lib/ld-linux"* || true
