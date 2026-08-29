#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/.build"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/Ledge.app"
MODULE_CACHE="$BUILD_DIR/ModuleCache"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"
export XDG_CACHE_HOME="$BUILD_DIR/cache"

if [[ -L "$BUILD_DIR" || -L "$DIST_DIR" ]]; then
    echo "Refusing to build: .build and dist must not be symbolic links." >&2
    exit 1
fi

EXPECTED_DIST="${PROJECT_DIR:A}/dist"
EXPECTED_BUILD="${PROJECT_DIR:A}/.build"
/bin/mkdir -p "$DIST_DIR" "$BUILD_DIR"
if [[ "${DIST_DIR:A}" != "$EXPECTED_DIST" || "${BUILD_DIR:A}" != "$EXPECTED_BUILD" ]]; then
    echo "Refusing to build outside the project build directories." >&2
    exit 1
fi

cd "$PROJECT_DIR"
if [[ "${LEDGE_SKIP_SWIFT_BUILD:-0}" == "1" ]]; then
    if [[ ! -x "$BUILD_DIR/release/Ledge" ]]; then
        echo "Cannot skip Swift build: release executable is missing." >&2
        exit 1
    fi
else
    swift build -c release --disable-sandbox --jobs 1
fi

STAGING_ROOT="$(/usr/bin/mktemp -d "/private/tmp/ledge-build.XXXXXX")"
STAGING_DIR="$STAGING_ROOT/Ledge.app"
trap '/bin/rm -rf "$STAGING_ROOT"' EXIT

/bin/mkdir -p "$STAGING_DIR/Contents/MacOS"
/bin/mkdir -p "$STAGING_DIR/Contents/Resources"
/bin/cp "$BUILD_DIR/release/Ledge" "$STAGING_DIR/Contents/MacOS/Ledge"
/bin/cp "$PROJECT_DIR/Resources/Info.plist" "$STAGING_DIR/Contents/Info.plist"
/bin/cp "$PROJECT_DIR/Resources/LedgeGreen.icns" "$STAGING_DIR/Contents/Resources/LedgeGreen.icns"
/bin/cp "$PROJECT_DIR/Resources/Assets.car" "$STAGING_DIR/Contents/Resources/Assets.car"
/bin/chmod 755 "$STAGING_DIR/Contents/MacOS/Ledge"

/usr/bin/plutil -lint "$STAGING_DIR/Contents/Info.plist"
/usr/bin/xattr -cr "$STAGING_DIR"
SIGN_IDENTITY="${LEDGE_SIGN_IDENTITY:--}"
SIGN_ARGUMENTS=(--force --deep --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN_ARGUMENTS+=(--options runtime --timestamp)
fi
/usr/bin/codesign "${SIGN_ARGUMENTS[@]}" "$STAGING_DIR"
/usr/bin/codesign --verify --deep --strict "$STAGING_DIR"

if [[ -L "$APP_DIR" ]]; then
    echo "Refusing to replace a symbolic-link app bundle." >&2
    exit 1
fi
if [[ -e "$APP_DIR" ]]; then
    /bin/rm -rf "$APP_DIR"
fi
/bin/mv "$STAGING_DIR" "$APP_DIR"

echo "$APP_DIR"
