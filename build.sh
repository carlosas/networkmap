#!/bin/bash
set -e

APP_NAME="NetworkMap"
BUNDLE_ID="com.carlosas.networkmap"
EXECUTABLE_PATH=".build/release/$APP_NAME"

# VERSION is the human-readable version string (e.g. "0.0.1-alpha15")
# In CI it's set via GITHUB_ENV from the git tag; locally derive from latest tag
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0-dev")
fi

# BUILD_NUMBER must be a numeric integer for Sparkle version comparison
# In CI it's set via GITHUB_ENV; locally default to git commit count or 1
if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
fi
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 1a. Build nmap from source (cached)
NMAP_VERSION="7.95"
NMAP_BUILD_DIR=".build/nmap-build"
NMAP_BINARY=".build/nmap-build/nmap-${NMAP_VERSION}/nmap"

if [ ! -f "$NMAP_BINARY" ]; then
    echo "Building nmap ${NMAP_VERSION} from source..."
    mkdir -p "$NMAP_BUILD_DIR"
    if [ ! -d "$NMAP_BUILD_DIR/nmap-${NMAP_VERSION}" ]; then
        curl -fL -o "$NMAP_BUILD_DIR/nmap.tar.bz2" "https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"
        tar -xjf "$NMAP_BUILD_DIR/nmap.tar.bz2" -C "$NMAP_BUILD_DIR"
        rm "$NMAP_BUILD_DIR/nmap.tar.bz2"
    fi
    pushd "$NMAP_BUILD_DIR/nmap-${NMAP_VERSION}" > /dev/null
    # Fix autotools timestamp issues from tarball extraction
    find . -name '*.m4' -o -name 'configure' -o -name 'Makefile.in' -o -name 'config.h.in' | xargs touch
    ./configure --without-openssl --without-nping --without-zenmap --without-ncat --without-ndiff --without-nmap-update
    make -j$(sysctl -n hw.ncpu)
    popd > /dev/null
else
    echo "Using cached nmap binary."
fi

# 1b. Build the executable
echo "Building $APP_NAME..."
swift build -c release

# 2. Create the bundle structure
echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy the binary
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

# 3b. Copy the app icon
if [ -f "Sources/NetworkMap/Resources/AppIcon.icns" ]; then
    cp "Sources/NetworkMap/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found in Sources/NetworkMap/Resources/"
fi

# 3c. Copy the menu bar icon resources
if [ -f "Sources/NetworkMap/Resources/MenuBarIcon.png" ]; then
    cp Sources/NetworkMap/Resources/MenuBarIcon*.png "$RESOURCES_DIR/"
else
    echo "Warning: MenuBarIcon.png not found in Sources/NetworkMap/Resources/"
fi

# 3d. Copy bundled nmap binary and data files
if [ -f "$NMAP_BINARY" ]; then
    NMAP_SRC_DIR="$NMAP_BUILD_DIR/nmap-${NMAP_VERSION}"
    NMAP_DEST_DIR="$RESOURCES_DIR/nmap"
    mkdir -p "$NMAP_DEST_DIR"
    cp "$NMAP_BINARY" "$NMAP_DEST_DIR/nmap"
    chmod +x "$NMAP_DEST_DIR/nmap"
    # Copy essential data files for MAC vendor lookup and service resolution
    for f in nmap-mac-prefixes nmap-services nmap-protocols nmap-payloads; do
        if [ -f "$NMAP_SRC_DIR/$f" ]; then
            cp "$NMAP_SRC_DIR/$f" "$NMAP_DEST_DIR/"
        fi
    done
else
    echo "Warning: nmap binary not found at $NMAP_BINARY"
fi

# 4. Create Info.plist (Inject Sparkle keys)
SPARKLE_PUBLIC_KEY="b/Hy6Z4l3zhbflqPidmweOacYNYrDsSvK+jfcBuPSo8="
SU_FEED_URL="https://carlosas.github.io/networkmap/appcast.xml"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SUFeedURL</key>
    <string>$SU_FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_KEY</string>
</dict>
</plist>
EOF

# 5. Embed Sparkle Framework
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

if [ -d ".build/release/Sparkle.framework" ]; then
    cp -R ".build/release/Sparkle.framework" "$FRAMEWORKS_DIR/"
    # Change rpath so the app can find the framework
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
else
    echo "Warning: Sparkle.framework not found in .build/release/"
fi


echo "Done! Run the app with: open $APP_BUNDLE"
