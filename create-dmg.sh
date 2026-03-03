#!/bin/bash
set -e

APP_NAME="NetworkMap"
APP_BUNDLE="$APP_NAME.app"
VERSION="${VERSION:-1.0}"
DMG_NAME="$APP_NAME-$VERSION.dmg"
VOLUME_NAME="$APP_NAME"
STAGING_DIR=$(mktemp -d)

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run ./build.sh first."
    exit 1
fi

echo "Creating DMG: $DMG_NAME"

# Stage the contents
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Remove any existing DMG
rm -f "$DMG_NAME"

# Create the DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

# Clean up
rm -rf "$STAGING_DIR"

echo "Done! Created $DMG_NAME"
