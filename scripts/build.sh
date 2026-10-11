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

/usr/bin/xcrun swift build -c release --product PodMiniPlayer \
  --disable-sandbox --manifest-cache local --cache-path "$project_dir/.build/cache/swiftpm"

app_dir="$project_dir/dist/Pod Mini Player.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/.build/release/PodMiniPlayer" "$app_dir/Contents/MacOS/PodMiniPlayer"
cp "$project_dir/AppInfo.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Vendor/MediaRemoteAdapter/bin/mediaremote-adapter.pl" "$app_dir/Contents/Resources/"
cp "$project_dir/Vendor/MediaRemoteAdapter/LICENSE" "$app_dir/Contents/Resources/MediaRemoteAdapter-LICENSE.txt"
ditto "$framework_dir" "$app_dir/Contents/Resources/MediaRemoteAdapter.framework"
cp "$adapter_dir/MediaRemoteAdapterTestClient" "$app_dir/Contents/Resources/"
/usr/bin/codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
