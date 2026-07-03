#!/bin/bash
# One-time setup: create a local code signing identity for Steward
# macOS Keychain sees this as a stable identity — no more dialog per build.
set -euo pipefail

NAME="Steward Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Check if already exists
if security find-identity 2>/dev/null | grep -q "$NAME"; then
  echo "✅ 签名证书已存在: $NAME"
  exit 0
fi

echo "创建本地签名证书: $NAME ..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

openssl genrsa -out "$TMPDIR/key.pem" 2048 2>/dev/null
openssl req -x509 -new -key "$TMPDIR/key.pem" -out "$TMPDIR/cert.pem" -days 36500 -nodes \
  -subj "/CN=$NAME" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" 2>/dev/null

openssl pkcs12 -export -in "$TMPDIR/cert.pem" -inkey "$TMPDIR/key.pem" \
  -out "$TMPDIR/cert.p12" -passout pass:steward -name "$NAME" 2>/dev/null

security import "$TMPDIR/cert.p12" -k "$KEYCHAIN" -P steward -T /usr/bin/codesign 2>&1

echo "✅ 签名证书已导入: $NAME"
security find-identity 2>/dev/null | grep "$NAME"
