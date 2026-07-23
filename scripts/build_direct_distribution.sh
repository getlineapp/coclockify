#!/usr/bin/env bash
set -euo pipefail

# Add path to xcrun/actool if needed, usually in /usr/bin or /usr/bin/xcrun


APP_NAME="Cocotrack"
BUNDLE_ID="com.cocolab.cocotrack"
EXECUTABLE_NAME="cocotrack"
MIN_MACOS_VERSION="13.0"
VERSION="2.3.2"
BUILD_NUMBER="11"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

ZIP_PATH="$DIST_DIR/$APP_NAME-macOS-v${VERSION}.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-macOS-v${VERSION}.dmg"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-}"
ALLOW_ADHOC="${ALLOW_ADHOC:-0}"

if [[ -z "$SIGN_IDENTITY" && "$ALLOW_ADHOC" != "1" ]]; then
  echo "ERROR: SIGN_IDENTITY (Developer ID Application certificate) is required." >&2
  echo "       Set SIGN_IDENTITY=... before running, or pass ALLOW_ADHOC=1 explicitly to opt into ad-hoc signing." >&2
  echo "       Ad-hoc signed bundles are blocked by Gatekeeper on first run and must never be published." >&2
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

mkdir -p "$DIST_DIR"

echo "[1/6] Building release binary"
swift build -c release

# The build triple was hardcoded to arm64, so this script failed outright on an
# Intel host. `swift build --show-bin-path` reports the real output directory.
BIN_PATH="$(swift build -c release --show-bin-path)"
RELEASE_BIN="$BIN_PATH/$EXECUTABLE_NAME"
if [[ ! -f "$RELEASE_BIN" ]]; then
  echo "Release binary not found: $RELEASE_BIN" >&2
  exit 1
fi

echo "Binary architectures: $(lipo -archs "$RELEASE_BIN" 2>/dev/null || echo unknown)"
if ! lipo -archs "$RELEASE_BIN" 2>/dev/null | grep -q x86_64; then
  echo "NOTE: this build is Apple-Silicon only and will not launch on Intel Macs." >&2
fi

echo "[2/6] Creating .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$RELEASE_BIN" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

mkdir -p "$RESOURCES_DIR"

RESOURCE_BUNDLE="$BIN_PATH/cocotrack_cocotrack.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/cocotrack_cocotrack.bundle"
    echo "Copied SwiftPM resource bundle"
else
    echo "Warning: SwiftPM resource bundle not found at $RESOURCE_BUNDLE"
fi

echo "[2.5/6] Compiling Assets"
if [[ -d "$ROOT_DIR/Sources/cocotrack/Resources/cocotrack.xcassets" ]]; then
    xcrun actool "$ROOT_DIR/Sources/cocotrack/Resources/cocotrack.xcassets" --compile "$RESOURCES_DIR" --platform macosx --minimum-deployment-target "$MIN_MACOS_VERSION" --app-icon AppIcon --output-partial-info-plist "$BUILD_DIR/assets-Info.plist" >/dev/null
    echo "Compiled Assets.car"
else
    echo "Warning: No asset catalog found at Sources/cocotrack/Resources/cocotrack.xcassets"
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

echo "[3/6] Signing app bundle"
# `--deep` is documented by Apple as unsuitable for signing (it re-signs nested
# content with the outer options and skips entitlements). The MAS pipeline already
# signs this same bundle shape without it; --verify --deep --strict below confirms.
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
  echo "Signed with identity: $SIGN_IDENTITY"
else
  codesign --force --sign - "$APP_DIR"
  echo "Signed ad-hoc (SIGN_IDENTITY not provided)."
fi

codesign --verify --deep --strict "$APP_DIR"

echo "[4/6] Creating ZIP"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "[5/6] Creating DMG"
rm -f "$DMG_PATH"
TMP_DMG_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DMG_DIR"' EXIT
cp -R "$APP_DIR" "$TMP_DMG_DIR/"
hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DMG_PATH" > /dev/null

if [[ -n "$SIGN_IDENTITY" ]]; then
  # This used to end in `|| true`, so a failed DMG signature produced a
  # green build and an unsigned artifact.
  codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo "[6/6] Optional notarization"
if [[ -n "$NOTARIZE_PROFILE" && -n "$SIGN_IDENTITY" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARIZE_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  xcrun stapler staple "$DMG_PATH"
  echo "Notarization completed."
else
  echo "Skipped notarization (set SIGN_IDENTITY and NOTARIZE_PROFILE to enable)."
fi

echo
ls -lh "$APP_DIR" "$ZIP_PATH" "$DMG_PATH"
echo
echo "Artifacts ready in: $DIST_DIR"
