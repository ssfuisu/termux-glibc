#!/bin/bash
# Generate a new fixed release keystore.
# Run once via the keystore-init workflow, then store output as GitHub Secrets.
# Never commit the real keystore.
set -euo pipefail

OUT="${1:-release.keystore}"
ALIAS="${ALIAS:-termuxglibc}"
STOREPASS="${STOREPASS:?set STOREPASS env}"
KEYPASS="${KEYPASS:?set KEYPASS env}"

keytool -genkeypair \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10950 \
  -storepass "$STOREPASS" -keypass "$KEYPASS" \
  -dname "CN=TermuxGlibc, OU=Release, O=TermuxGlibc, L=Unknown, ST=Unknown, C=US"

echo "Keystore created: $OUT"
echo "Base64 (store as KEYSTORE_BASE64 secret):"
base64 -w0 "$OUT"
echo ""
