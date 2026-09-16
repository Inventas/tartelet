#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
XCODEGEN_BIN="${XCODEGEN:-xcodegen}"
VERSION="${TARTELET_VERSION:-0.13.0}"
BUILD_NUMBER="${TARTELET_BUILD_NUMBER:-1}"
RELEASE_LABEL="${TARTELET_RELEASE_LABEL:-${VERSION}-inventas.${BUILD_NUMBER}}"
BUNDLE_ID="${TARTELET_BUNDLE_ID:-com.inventas.Tartelet}"
SIGNING_IDENTITY="${TARTELET_SIGNING_IDENTITY:--}"
NOTARY_PROFILE="${TARTELET_NOTARY_PROFILE:-}"

if [[ ! "$RELEASE_LABEL" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "TARTELET_RELEASE_LABEL must contain only letters, numbers, dots, underscores, and hyphens." >&2
  exit 1
fi
if ! command -v "$XCODEGEN_BIN" >/dev/null; then
  echo "Install XcodeGen, or set XCODEGEN to its executable path." >&2
  exit 1
fi
if [[ -n "$NOTARY_PROFILE" && "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Notarization requires TARTELET_SIGNING_IDENTITY to name a Developer ID Application certificate." >&2
  exit 1
fi

REVISION="$(git rev-parse HEAD)"
SOURCE_LABEL="$(git rev-parse --short HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then
  SOURCE_LABEL="${SOURCE_LABEL}-dirty"
  echo "Warning: this build includes uncommitted changes." >&2
fi
OUTPUT_DIR="$ROOT_DIR/build/Distribution/${RELEASE_LABEL}-${SOURCE_LABEL}-$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$OUTPUT_DIR/Tartelet.xcarchive"
APP="$OUTPUT_DIR/Tartelet.app"
ZIP_NAME="Tartelet-${RELEASE_LABEL}-macos-arm64.zip"
mkdir -p "$OUTPUT_DIR"

SIGNING=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY" CODE_SIGN_ENTITLEMENTS=)
SIGNING_DESCRIPTION="Ad-hoc signed; not notarized"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  SIGNING+=(DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO)
else
  if [[ "$SIGNING_IDENTITY" != "Developer ID Application: "* || -z "${TARTELET_DEVELOPMENT_TEAM:-}" ]]; then
    echo "Set a Developer ID Application identity and TARTELET_DEVELOPMENT_TEAM for distribution signing." >&2
    exit 1
  fi
  SIGNING+=("DEVELOPMENT_TEAM=$TARTELET_DEVELOPMENT_TEAM" ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp)
  SIGNING_DESCRIPTION="Developer ID signed; not notarized"
fi

"$XCODEGEN_BIN" generate
xcodebuild -project Tartelet.xcodeproj -scheme Tartelet -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$ROOT_DIR/build/DistributionDerivedData" \
  -archivePath "$ARCHIVE" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  "TARTELET_BUNDLE_IDENTIFIER=$BUNDLE_ID" "MARKETING_VERSION=$VERSION" "CURRENT_PROJECT_VERSION=$BUILD_NUMBER" \
  "${SIGNING[@]}" archive

ditto "$ARCHIVE/Products/Applications/Tartelet.app" "$APP"
codesign --verify --deep --strict "$APP"
test "$(lipo -archs "$APP/Contents/MacOS/Tartelet")" = arm64
# Resource bundles need their own identifiers for image and localization lookup.
while IFS= read -r -d '' RESOURCE_INFO; do
  RESOURCE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$RESOURCE_INFO")
  if [[ "$RESOURCE_ID" == "$BUNDLE_ID" ]]; then
    echo "Resource bundle uses the app identifier: $RESOURCE_INFO" >&2
    exit 1
  fi
done < <(find "$APP/Contents/Resources" -path '*.bundle/Contents/Info.plist' -print0)

if [[ -n "$NOTARY_PROFILE" ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_DIR/notarization-upload.zip"
  xcrun notarytool submit "$OUTPUT_DIR/notarization-upload.zip" --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format json > "$OUTPUT_DIR/notarization.json"
  if [[ "$(plutil -extract status raw -o - "$OUTPUT_DIR/notarization.json")" != "Accepted" ]]; then
    echo "Notarization failed. See $OUTPUT_DIR/notarization.json" >&2
    exit 1
  fi
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
  SIGNING_DESCRIPTION="Developer ID signed and notarized"
fi

codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_DIR/$ZIP_NAME"
unzip -tq "$OUTPUT_DIR/$ZIP_NAME"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ZIP_NAME" > SHA256SUMS.txt
)
cat > "$OUTPUT_DIR/BUILD-INFO.txt" <<INFO
Tartelet $RELEASE_LABEL
Version: $VERSION ($BUILD_NUMBER)
Source revision: $REVISION
Source state: $SOURCE_LABEL
Bundle identifier: $BUNDLE_ID
Architecture: arm64 (Apple Silicon)
Minimum macOS: 14.0
Signing: $SIGNING_DESCRIPTION
$(xcodebuild -version)
INFO
printf '%s\n' "$OUTPUT_DIR" > "$ROOT_DIR/build/Distribution/latest-path.txt"
printf '\n%s\n%s\n' "$SIGNING_DESCRIPTION" "$OUTPUT_DIR/$ZIP_NAME"
