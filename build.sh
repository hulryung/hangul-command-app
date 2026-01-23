#!/bin/bash

# Build script for HangulCommandApp
# This script creates a distributable macOS application package

set -e

APP_NAME="HangulCommandApp"
VERSION="1.0.0"
BUNDLE_ID="com.hulryung.hangulcommandapp"
DEVELOPER_NAME="Your Developer Name" # TODO: Update with actual developer name

echo "🔨 Building $APP_NAME v$VERSION..."

# Clean previous builds
if [ -d "build" ]; then
    rm -rf build
fi

# Create build directory
mkdir -p build
cd build

# Build the app
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    -archivePath build/Archive \
    -archivePath build/Archive.xcarchive \
    CODE_SIGN_IDENTITY="Developer ID Application: $DEVELOPER_NAME" \
    CODE_SIGN_ENTITLEMENTS="$APP_NAME/$APP_NAME.entitlements" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    PRODUCT_NAME="$APP_NAME" \
    PRODUCT_VERSION="$VERSION"

echo "✅ Build completed"

# Create app bundle for distribution
if [ -d "Archive.xcarchive" ]; then
    echo "📦 Exporting app for distribution..."
    
    # Export the app
    xcodebuild -exportArchive \
        -archivePath build/Archive.xcarchive \
        -exportPath build/Export \
        -exportOptionsPlist exportOptions.plist \
        -exportFormat app
    
    echo "✅ Export completed"
else
    echo "❌ Archive not found"
    exit 1
fi

# Create DMG for distribution
echo "💿 Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION"

# Create temporary DMG folder
mkdir -p dmg_temp

# Copy app to DMG folder
cp -R "Export/$APP_NAME.app" dmg_temp/

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder dmg_temp \
    -ov -format UDZO \
    "$DMG_NAME.dmg"

# Cleanup
rm -rf dmg_temp build

echo "✅ DMG created: $DMG_NAME.dmg"

# Create zip for GitHub release
echo "📦 Creating zip for GitHub..."
ZIP_NAME="$APP_NAME-$VERSION"

# Create zip
ditto -c -k --sequesterRsrc "Export/$APP_NAME.app" "$ZIP_NAME.zip"

echo "✅ Zip created: $ZIP_NAME.zip"

# Display results
ls -la *.dmg *.zip 2>/dev/null || true

echo "🎯 Build process completed!"
echo "📂 Files created:"
echo "  - $ZIP_NAME.zip (for GitHub release)"
echo "  - $DMG_NAME.dmg (for direct distribution)"