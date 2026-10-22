#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export XDG_CACHE_HOME="$project_dir/.build/cache"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/cache/clang"
export SWIFT_MODULE_CACHE_PATH="$project_dir/.build/cache/swift"
mkdir -p "$XDG_CACHE_HOME" "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULE_CACHE_PATH"
adapter_dir="$project_dir/.build/adapter"
framework_dir="$adapter_dir/MediaRemoteAdapter.framework"
mkdir -p "$framework_dir"

/usr/bin/xcrun --sdk macosx clang \
  -dynamiclib -fobjc-arc -fvisibility=default \
  -I Vendor/MediaRemoteAdapter/include \
  -I Vendor/MediaRemoteAdapter/src \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  Vendor/MediaRemoteAdapter/src/adapter/*.m \
  Vendor/MediaRemoteAdapter/src/private/*.m \
  Vendor/MediaRemoteAdapter/src/utility/*.m \
  -o "$framework_dir/MediaRemoteAdapter"

/usr/bin/codesign --force --sign - "$framework_dir"

/usr/bin/xcrun --sdk macosx clang \
  -fobjc-arc -framework Foundation -framework MediaPlayer \
  -I Vendor/MediaRemoteAdapter/src/test \
  Vendor/MediaRemoteAdapter/src/test/*.m \
  -o "$adapter_dir/MediaRemoteAdapterTestClient"

/usr/bin/xcrun swift build -c release --product PodLilt \
  --disable-sandbox --manifest-cache local --cache-path "$project_dir/.build/cache/swiftpm"

app_dir="$project_dir/dist/PodLilt.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
rm -f "$app_dir/Contents/MacOS/PodMiniPlayer"
cp "$project_dir/.build/release/PodLilt" "$app_dir/Contents/MacOS/PodLilt"
cp "$project_dir/AppInfo.plist" "$app_dir/Contents/Info.plist"
icon_source="$project_dir/Resources/AppIcon.png"
iconset_dir="$project_dir/.build/AppIcon.iconset"
mkdir -p "$iconset_dir"
for icon_size in 16 32 128 256 512; do
  retina_size=$((icon_size * 2))
  /usr/bin/sips -z "$icon_size" "$icon_size" "$icon_source" \
    --out "$iconset_dir/icon_${icon_size}x${icon_size}.png" >/dev/null
  /usr/bin/sips -z "$retina_size" "$retina_size" "$icon_source" \
    --out "$iconset_dir/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/AppIcon.icns"
cp "$project_dir/Vendor/MediaRemoteAdapter/bin/mediaremote-adapter.pl" "$app_dir/Contents/Resources/"
cp "$project_dir/Vendor/MediaRemoteAdapter/LICENSE" "$app_dir/Contents/Resources/MediaRemoteAdapter-LICENSE.txt"
ditto "$framework_dir" "$app_dir/Contents/Resources/MediaRemoteAdapter.framework"
cp "$adapter_dir/MediaRemoteAdapterTestClient" "$app_dir/Contents/Resources/"
xattr -dr com.apple.quarantine "$app_dir" 2>/dev/null || true
/usr/bin/codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
