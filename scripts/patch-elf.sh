#!/bin/bash
# Rewrite ELF interpreter to the fixed on-device glibc loader.
# Usage: patch-elf.sh <file|dir> [aarch64|arm]
set -euo pipefail

TARGET="${1:?usage: patch-elf.sh <file|dir> [arch]}"
ARCH="${2:-aarch64}"

if [ "$ARCH" = "aarch64" ]; then
  INTERP="/data/data/com.termux.glibc/files/usr/glibc/lib/ld-linux-aarch64.so.1"
else
  INTERP="/data/data/com.termux.glibc/files/usr/glibc/lib/ld-linux-armhf.so.3"
fi

patch_one() {
  local f="$1"
  if patchelf --print-interpreter "$f" >/dev/null 2>&1; then
    echo "patch $f -> $INTERP"
    patchelf --set-interpreter "$INTERP" "$f"
  fi
}

if [ -f "$TARGET" ]; then
  patch_one "$TARGET"
else
  find "$TARGET" -type f -executable -print0 | while IFS= read -r -d '' f; do
    patch_one "$f" || true
  done
fi
