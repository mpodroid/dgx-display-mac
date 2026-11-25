#!/bin/sh
# Build the menu-bar app. The test parses a fixture SS1 line and does not SSH.
set -eu
cd "$(dirname "$0")/.."

swift test
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"

app="DGX Display.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/DGXDisplay" "$app/Contents/MacOS/DGXDisplay"
chmod 755 "$app/Contents/MacOS/DGXDisplay"

cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>DGXDisplay</string>
  <key>CFBundleIdentifier</key>
  <string>dgx.display-mac</string>
  <key>CFBundleName</key>
  <string>DGX Display</string>
  <key>CFBundleDisplayName</key>
  <string>DGX Display</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSLocalNetworkUsageDescription</key>
  <string>DGX Display reads the head Spark status feed over SSH on your local network.</string>
</dict>
</plist>
EOF

# Local Network privacy tracks a signed bundle identity. An Apple Development
# identity stays stable across rebuilds. Ad-hoc signing is the fallback.
identity="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)"
if [ -z "$identity" ]; then
    identity="-"
fi
codesign --force --sign "$identity" --timestamp=none "$app"

echo "built $(pwd)/$app"
