#!/bin/bash
# Fail CI if non-English content or emoji is introduced in fork-owned files.
# Scope is limited to files owned by this fork. Upstream Termux files are
# excluded because their wording is kept as is.
# Repo policy for fork files: English only, no emoji.
set -euo pipefail

PATHS=(
  README.md
  CONTRIBUTING.md
  keystore.properties.example
  glibc
  scripts
  packages
  app/src/main/java/com/termux/glibc
  .github/workflows/glibc-release.yml
  .github/workflows/keystore-init.yml
)

echo "Checking fork files for emoji..."
# Emoji ranges: emoticons, symbols, transport, dingbats, flags.
if grep -rP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]' \
  --exclude-dir=.git --exclude='*.png' --exclude='*.zip' "${PATHS[@]}"; then
  echo "ERROR: emoji found. Remove emoji."
  exit 1
fi

echo "Checking fork files for Turkish characters..."
# Unicode escapes are used so this script does not match itself.
# c-cedilla U+00E7, G-breve U+011F/011E, dotless i U+0131/0130,
# o-umlaut U+00F6/00D6, s-cedilla U+015F/015E, u-umlaut U+00FC/00DC.
if grep -rP '[\x{00E7}\x{00C7}\x{011F}\x{011E}\x{0131}\x{0130}\x{00F6}\x{00D6}\x{015F}\x{015E}\x{00FC}\x{00DC}]' \
  --exclude='check-english.sh' \
  --include='*.md' --include='*.gradle' --include='*.java' --include='*.xml' --include='*.yml' --include='*.sh' "${PATHS[@]}"; then
  echo "ERROR: Turkish characters found. Use English only."
  exit 1
fi

echo "Language check passed."
