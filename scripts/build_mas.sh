#!/usr/bin/env bash
set -euo pipefail

# Mac App Store build pipeline for Cocotrack.
#
# Required env vars (set these before running):
#   APP_SIGN_IDENTITY      — e.g. "3rd Party Mac Developer Application: Cocolab sp. z o.o. (TEAMID)"
#   INSTALLER_SIGN_IDENTITY — e.g. "3rd Party Mac Developer Installer: Cocolab sp. z o.o. (TEAMID)"
#   PROVISION_PROFILE      — path to the embedded.provisionprofile for com.cocolab.cocotrack
#
# Optional:
#   VERSION / BUILD_NUMBER — override the defaults below
#   ASC_API_KEY_ID / ASC_API_ISSUER_ID — if both set, uploads via `xcrun altool`
#     using App Store Connect API key authentication. The .p8 key file must be
#     in one of Apple's standard search paths (e.g. ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8).
#     Generate keys at https://appstoreconnect.apple.com/access/api
#
# Legacy (deprecated, do not use): APPLE_ID / APP_SPECIFIC_PASSWORD on the command line
# leaks credentials to `ps` for any user-level process. Use ASC API keys instead.

APP_NAME="Cocotrack"
BUNDLE_ID="com.cocolab.cocotrack"
EXECUTABLE_NAME="cocotrack"
MIN_MACOS_VERSION="13.0"
VERSION="${VERSION:-2.3.2}"
BUILD_NUMBER="${BUILD_NUMBER:-11}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist-mas"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PKG_PATH="$DIST_DIR/$APP_NAME-mas-v${VERSION}.pkg"
ENTITLEMENTS="$ROOT_DIR/scripts/cocotrack.entitlements"

: "${APP_SIGN_IDENTITY:?Set APP_SIGN_IDENTITY (3rd Party Mac Developer Application certificate)}"
: "${INSTALLER_SIGN_IDENTITY:?Set INSTALLER_SIGN_IDENTITY (3rd Party Mac Developer Installer certificate)}"
: "${PROVISION_PROFILE:?Set PROVISION_PROFILE (path to embedded.provisionprofile)}"

if [[ ! -f "$PROVISION_PROFILE" ]]; then
  echo "Provisioning profile not found: $PROVISION_PROFILE" >&2
  exit 1
fi

# Validate version format to prevent XML injection through heredoc plist generation.
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "ERROR: VERSION must be numeric dotted (e.g. 2.2.0), got: $VERSION" >&2
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERROR: BUILD_NUMBER must be numeric, got: $BUILD_NUMBER" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "[1/7] Building release binary"
swift build -c release

# Was a hardcoded arm64 triple, which breaks on an Intel host and silently ships
# an Apple-Silicon-only binary.
BIN_PATH="$(swift build -c release --show-bin-path)"
RELEASE_BIN="$BIN_PATH/$EXECUTABLE_NAME"
if [[ ! -f "$RELEASE_BIN" ]]; then
  echo "Release binary not found: $RELEASE_BIN" >&2
  exit 1
fi

echo "Binary architectures: $(lipo -archs "$RELEASE_BIN" 2>/dev/null || echo unknown)"
if ! lipo -archs "$RELEASE_BIN" 2>/dev/null | grep -q x86_64; then
  echo "NOTE: App Store listing will be Apple-Silicon only — Intel Macs cannot install it." >&2
fi

echo "[2/7] Creating .app bundle"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$RELEASE_BIN" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$BIN_PATH/cocotrack_cocotrack.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/cocotrack_cocotrack.bundle"
  RES_PLIST="$RESOURCES_DIR/cocotrack_cocotrack.bundle/Info.plist"
  plutil -replace CFBundleIdentifier -string "$BUNDLE_ID.resources" "$RES_PLIST"
  plutil -replace CFBundleName -string "cocotrack_cocotrack" "$RES_PLIST"
  plutil -replace CFBundlePackageType -string "BNDL" "$RES_PLIST"
  plutil -replace CFBundleInfoDictionaryVersion -string "6.0" "$RES_PLIST"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$RES_PLIST"
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$RES_PLIST"
fi

echo "[3/7] Compiling Assets"
if [[ -d "$ROOT_DIR/Sources/cocotrack/Resources/cocotrack.xcassets" ]]; then
  xcrun actool "$ROOT_DIR/Sources/cocotrack/Resources/cocotrack.xcassets" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target "$MIN_MACOS_VERSION" \
    --app-icon AppIcon \
    --output-partial-info-plist "$BUILD_DIR/assets-Info.plist" >/dev/null
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Cocolab sp. z o.o.</string>
</dict>
</plist>
PLIST

echo "[4/7] Embedding provisioning profile"
cp "$PROVISION_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"

echo "[5/7] Signing app bundle"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$APP_SIGN_IDENTITY" \
  "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
codesign -d --entitlements :- "$APP_DIR"

echo "[6/7] Building installer .pkg"
productbuild \
  --component "$APP_DIR" /Applications \
  --sign "$INSTALLER_SIGN_IDENTITY" \
  "$PKG_PATH"

echo "[7/7] Optional upload"
if [[ -n "${APPLE_ID:-}" || -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "ERROR: APPLE_ID/APP_SPECIFIC_PASSWORD env vars are no longer supported." >&2
  echo "       Passing them to altool exposes credentials via ps. Use ASC_API_KEY_ID/ASC_API_ISSUER_ID instead." >&2
  exit 1
fi

if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
  xcrun altool --upload-app \
    --file "$PKG_PATH" \
    --type macos \
    --apiKey "$ASC_API_KEY_ID" \
    --apiIssuer "$ASC_API_ISSUER_ID"
  echo "Uploaded to App Store Connect."
else
  echo "Skipped upload. Use Transporter.app or set ASC_API_KEY_ID / ASC_API_ISSUER_ID to upload via altool."
fi

echo
ls -lh "$APP_DIR" "$PKG_PATH"
echo
echo "MAS artifact ready: $PKG_PATH"
