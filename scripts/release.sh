#!/usr/bin/env bash
# HexKoc'i arşivleyip TestFlight'a yükler.
#
# Gereksinim: App Store Connect API anahtarı
#   ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
#
# Kullanım:
#   ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-... ./scripts/release.sh
#   ./scripts/release.sh --build-only     (yüklemeden sadece arşivle)

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="7JZLNNY795"
SCHEME="HexKoc"
ARCHIVE="build/HexKoc.xcarchive"
KEY_ID="${ASC_KEY_ID:-}"
ISSUER_ID="${ASC_ISSUER_ID:-2b798c52-072f-470e-8808-fe953150cba6}"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
BUILD_ONLY=false
[[ "${1:-}" == "--build-only" ]] && BUILD_ONLY=true

if [[ -z "$KEY_ID" ]]; then
  # Tek bir anahtar varsa onu kullan
  found=$(ls "$HOME/.appstoreconnect/private_keys/"AuthKey_*.p8 2>/dev/null | head -1 || true)
  if [[ -n "$found" ]]; then
    KEY_ID=$(basename "$found" | sed 's/AuthKey_\(.*\)\.p8/\1/')
    KEY_PATH="$found"
    echo "→ API anahtarı bulundu: $KEY_ID"
  else
    echo "HATA: ASC_KEY_ID verilmedi ve ~/.appstoreconnect/private_keys/ içinde .p8 yok." >&2
    exit 1
  fi
fi

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$KEY_ID"
      -authenticationKeyIssuerID "$ISSUER_ID")

# Build numarasını her seferinde artır: TestFlight aynı numarayı iki kez kabul etmiyor.
NEXT_BUILD=$(date +%Y%m%d%H%M)
echo "→ Build numarası: $NEXT_BUILD"

echo "→ Proje üretiliyor"
xcodegen generate

echo "→ Arşivleniyor"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project HexKoc.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  CURRENT_PROJECT_VERSION="$NEXT_BUILD" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  "${AUTH[@]}"

if $BUILD_ONLY; then
  echo "✓ Arşiv hazır: $ARCHIVE"
  exit 0
fi

echo "→ TestFlight'a yükleniyor"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export \
  "${AUTH[@]}"

echo "✓ Yüklendi. İşlenmesi 5-15 dakika sürer; sonra TestFlight'ta görünür."
