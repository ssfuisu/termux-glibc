#!/bin/bash
# Assemble bootstrap zip from a glibc sysroot.
# Usage: make-bootstrap.sh <sysroot> <output.zip> [aarch64|arm]
# The zip layout is relative to $FILES_DIR (contains usr/...).
set -euo pipefail

SYSROOT="${1:?usage: make-bootstrap.sh <sysroot> <output.zip> [arch]}"
OUTPUT="${2:?usage: make-bootstrap.sh <sysroot> <output.zip> [arch]}"
ARCH="${3:-aarch64}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/usr/glibc" "$STAGE/usr/bin" "$STAGE/usr/tmp" "$STAGE/usr/etc/tls"
cp -a "$SYSROOT/." "$STAGE/usr/glibc/"

# Wrapper scripts in bionic prefix that forward to the glibc loader.
if [ "$ARCH" = "aarch64" ]; then
  LOADER_ABS="/data/data/com.termux.glibc/files/usr/glibc/lib/ld-linux-aarch64.so.1"
else
  LOADER_ABS="/data/data/com.termux.glibc/files/usr/glibc/lib/ld-linux-armhf.so.3"
fi

cat > "$STAGE/usr/bin/glibc-run" <<EOF
#!/system/bin/sh
# Auto-generated. Do not edit.
PREFIX="/data/data/com.termux.glibc/files/usr"
GLIBC_PREFIX="\$PREFIX/glibc"
LOADER="$LOADER_ABS"
LIBPATH="\$GLIBC_PREFIX/lib:\$GLIBC_PREFIX/usr/lib"
export LD_LIBRARY_PATH="\$LIBPATH"
export PREFIX GLIBC_PREFIX
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
exec "\$LOADER" --library-path "\$LIBPATH" "\$@"
EOF
chmod +x "$STAGE/usr/bin/glibc-run"

cat > "$STAGE/usr/bin/login" <<EOF
#!/system/bin/sh
PREFIX="/data/data/com.termux.glibc/files/usr"
GLIBC_PREFIX="\$PREFIX/glibc"
exec "\$PREFIX/bin/glibc-run" "\$GLIBC_PREFIX/bin/bash" --login
EOF
chmod +x "$STAGE/usr/bin/login"

# Default resolv.conf inside glibc etc.
mkdir -p "$STAGE/usr/glibc/etc"
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$STAGE/usr/glibc/etc/resolv.conf"

# Copy pkg-glibc if available.
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$SCRIPT_DIR/packages/pkg-glibc" ]; then
  cp "$SCRIPT_DIR/packages/pkg-glibc" "$STAGE/usr/bin/pkg-glibc"
  chmod +x "$STAGE/usr/bin/pkg-glibc"
  cp "$SCRIPT_DIR/packages/core.list" "$STAGE/usr/etc/pkg-core.list" 2>/dev/null || true
fi

rm -f "$OUTPUT"
(cd "$STAGE" && zip -qr "$OUTPUT" .)
echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
unzip -l "$OUTPUT" | head -30
