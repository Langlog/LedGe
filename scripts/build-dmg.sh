#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/Ledge.app"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
BACKGROUND="$PROJECT_DIR/Resources/DMG/background.png"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
VOLUME_NAME="Ledge $VERSION"
LAYOUT_VOLUME_NAME="LedgeLayout-$$"
DMG_PATH="$DIST_DIR/Ledge-$VERSION.dmg"
SIGN_IDENTITY="${LEDGE_SIGN_IDENTITY:--}"

"$PROJECT_DIR/scripts/build-app.sh" >/dev/null

if [[ -L "$DIST_DIR" || -L "$APP_DIR" ]]; then
    echo "Refusing to package symbolic-link build paths." >&2
    exit 1
fi

EXPECTED_DIST="${PROJECT_DIR:A}/dist"
if [[ "${DIST_DIR:A}" != "$EXPECTED_DIST" ]]; then
    echo "Refusing to package outside the project dist directory." >&2
    exit 1
fi

STAGING_ROOT="$(/usr/bin/mktemp -d "/private/tmp/ledge-dmg.XXXXXX")"
STAGING_DIR="$STAGING_ROOT/staging"
MOUNT_DIR="/Volumes/$LAYOUT_VOLUME_NAME"
RW_DMG="$STAGING_ROOT/Ledge-rw.dmg"
TEMP_DMG="$STAGING_ROOT/Ledge-$VERSION.dmg"
DEVICE=""

cleanup() {
    if [[ -n "$DEVICE" ]]; then
        /usr/bin/hdiutil detach "$DEVICE" >/dev/null 2>&1 || true
    fi
    /bin/rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

/bin/mkdir -p "$STAGING_DIR/.background"
/usr/bin/ditto --noextattr "$APP_DIR" "$STAGING_DIR/Ledge.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/cp "$PROJECT_DIR/Resources/DMG-README.txt" "$STAGING_DIR/安装说明.txt"
/bin/cp "$BACKGROUND" "$STAGING_DIR/.background/background.png"

/usr/bin/hdiutil create \
    -volname "$LAYOUT_VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$RW_DMG" >/dev/null

ATTACH_OUTPUT="$(/usr/bin/hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    "$RW_DMG")"
DEVICE="$(print -r -- "$ATTACH_OUTPUT" | /usr/bin/awk '/^\/dev\/disk/ {print $1; exit}')"
if [[ -z "$DEVICE" ]]; then
    echo "Could not identify the mounted DMG device." >&2
    exit 1
fi

/usr/bin/osascript \
    "$PROJECT_DIR/scripts/layout-dmg.applescript" \
    "$LAYOUT_VOLUME_NAME" \
    "$MOUNT_DIR/.background/background.png"
/bin/sync
/usr/sbin/diskutil renameVolume "$MOUNT_DIR" "$VOLUME_NAME" >/dev/null
/bin/sync
/usr/bin/hdiutil detach "$DEVICE" >/dev/null
DEVICE=""

/usr/bin/hdiutil convert \
    "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$TEMP_DMG" >/dev/null

/usr/bin/hdiutil verify "$TEMP_DMG" >/dev/null
DMG_SIGN_ARGUMENTS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    DMG_SIGN_ARGUMENTS+=(--timestamp)
fi
/usr/bin/codesign "${DMG_SIGN_ARGUMENTS[@]}" "$TEMP_DMG"
/usr/bin/codesign --verify --verbose=1 "$TEMP_DMG"

if [[ -L "$DMG_PATH" ]]; then
    echo "Refusing to replace a symbolic-link DMG." >&2
    exit 1
fi
if [[ -e "$DMG_PATH" ]]; then
    /bin/rm "$DMG_PATH"
fi
/bin/mv "$TEMP_DMG" "$DMG_PATH"

echo "$DMG_PATH"
