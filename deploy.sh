#!/bin/bash
# HeadCtrl auto-deploy: builds and installs to iPhone over local network

PROJ="/Users/jackduffy/ios-dev/HeadCtrl/HeadCtrl.xcodeproj"
SCHEME="HeadCtrl"
DERIVED="/tmp/headctrl-deploy"
DEVICE_UUID="12FAAEB8-1FEA-5AEE-A460-3960E5056152"

echo "==> Building HeadCtrl..."
xcodebuild \
  -project "$PROJ" \
  -scheme "$SCHEME" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED|CodeSign"

APP_PATH=$(find "$DERIVED/Build/Products/Debug-iphoneos" -name "HeadCtrl.app" -maxdepth 1 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  echo "ERROR: Build failed — run setup-codesign.sh in a Mac Terminal if this is a CodeSign error"
  exit 1
fi

echo "==> Installing to iPhone ($DEVICE_UUID)..."
xcrun devicectl device install app --device "$DEVICE_UUID" "$APP_PATH" \
  && echo "==> Done! HeadCtrl installed on iPhone." \
  || echo "ERROR: Install failed — phone must be on the same WiFi as this Mac"
