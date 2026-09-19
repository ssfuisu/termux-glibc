# termux-glibc

Termux fork with native glibc support. No proot. No virtualization.

This is a fork of [termux/termux-app](https://github.com/termux/termux-app).
The normal Termux bionic environment works as before. A glibc sysroot can
be installed next to it, and glibc binaries run directly through their own
loader (`ld-linux`).

Package: `com.termux.glibc`. Minimum Android 9 (API 28).

## Install

1. Open Releases.
2. Download the APK for your device:
   - `termux-glibc_*_arm64-v8a.apk` for 64-bit
   - `termux-glibc_*_armeabi-v7a.apk` for 32-bit
3. Install the APK and open the app. Termux bootstrap installs on first run.

## Use glibc

Install the glibc bootstrap from a release asset, then use the wrapper:

```
pkg-glibc update
pkg-glibc install curl
pkg-glibc run curl --version
pkg-glibc shell
```

The wrapper runs each binary through the glibc loader:

```
$PREFIX/glibc/lib/ld-linux-aarch64.so.1 \
  --library-path $PREFIX/glibc/lib:$PREFIX/glibc/usr/lib \
  $PREFIX/glibc/bin/bash --login
```

## How it works

- Bionic prefix: `files/usr` (Termux bootstrap, untouched).
- glibc sysroot: `files/usr/glibc` (installed by `GlibcInstaller`).
- Android and glibc share the Linux kernel, so no emulation is needed.
- Bootstrap zips are built in CI from glibc source (`glibc/build.sh`)
  and published as `glibc-bootstrap-aarch64.zip` and
  `glibc-bootstrap-arm.zip`.
- Upstream Termux docs are preserved in `docs/UPSTREAM-README.md`.

## Build

No local build is required. GitHub Actions builds everything.

1. Run the `Keystore Init` workflow once. Save the output as secrets:
   `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
2. Push to `main`. The `Glibc Release` workflow builds:
   - signed 64-bit APK
   - signed 32-bit APK
   - both glibc bootstrap zips
   - `CHECKSUMS.txt`
3. Each build creates a GitHub Release automatically.

Signing uses the same fixed keystore on every build. The real keystore
is never committed. See `keystore.properties.example`.

## Limitations

- The `applicationId` is part of the glibc loader path. Do not rename it.
- No `setuid`, no `systemd`. Packages that require systemd do not work.
- Android 12+ phantom process limits apply, same as upstream Termux.

## License

Same as upstream: GPL-3.0. See `LICENSE.md`.
