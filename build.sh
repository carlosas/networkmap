#!/bin/bash
set -e

APP_NAME="NetworkMap"
BUNDLE_ID="com.carlosas.networkmap"
EXECUTABLE_PATH=".build/release/$APP_NAME"

# BUILD_NUMBER must be a numeric integer for Sparkle version comparison
# In CI it's set via GITHUB_ENV; locally default to git commit count or 1
if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
fi
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 1. Build the executable
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
