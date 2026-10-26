#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

code_sign_identity="${CODE_SIGN_IDENTITY:--}"
app_version="${APP_VERSION:-}"
build_number="${BUILD_NUMBER:-}"

typeset -a codesign_flags
codesign_flags=(--force --sign "$code_sign_identity")
if [[ "$code_sign_identity" != "-" ]]; then
  codesign_flags+=(--timestamp --options runtime)
fi

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export XDG_CACHE_HOME="$project_dir/.build/cache"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/cache/clang"
export SWIFT_MODULE_CACHE_PATH="$project_dir/.build/cache/swift"
mkdir -p "$XDG_CACHE_HOME" "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULE_CACHE_PATH"
adapter_dir="$project_dir/.build/adapter"
framework_dir="$adapter_dir/MediaRemoteAdapter.framework"
rm -rf "$framework_dir"
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

/usr/bin/codesign "${codesign_flags[@]}" "$framework_dir/MediaRemoteAdapter"

/usr/bin/xcrun --sdk macosx clang \
  -fobjc-arc -framework Foundation -framework MediaPlayer \
  -I Vendor/MediaRemoteAdapter/src/test \
  Vendor/MediaRemoteAdapter/src/test/*.m \
  -o "$adapter_dir/MediaRemoteAdapterTestClient"

/usr/bin/codesign "${codesign_flags[@]}" "$adapter_dir/MediaRemoteAdapterTestClient"

/usr/bin/xcrun swift build -c release --product PodLilt \
  --disable-sandbox --manifest-cache local --cache-path "$project_dir/.build/cache/swiftpm"

app_dir="$project_dir/dist/PodLilt.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/.build/release/PodLilt" "$app_dir/Contents/MacOS/PodLilt"
cp "$project_dir/AppInfo.plist" "$app_dir/Contents/Info.plist"
if [[ -n "$app_version" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $app_version" "$app_dir/Contents/Info.plist"
fi
if [[ -n "$build_number" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_dir/Contents/Info.plist"
fi
icon_source="$project_dir/Resources/AppIcon.png"
/usr/bin/sips -s format icns "$icon_source" \
  --out "$app_dir/Contents/Resources/AppIcon.icns" >/dev/null
cp "$project_dir/Vendor/MediaRemoteAdapter/bin/mediaremote-adapter.pl" "$app_dir/Contents/Resources/"
cp "$project_dir/Vendor/MediaRemoteAdapter/LICENSE" "$app_dir/Contents/Resources/MediaRemoteAdapter-LICENSE.txt"
ditto "$framework_dir" "$app_dir/Contents/Resources/MediaRemoteAdapter.framework"
cp "$adapter_dir/MediaRemoteAdapterTestClient" "$app_dir/Contents/Resources/"
xattr -dr com.apple.quarantine "$app_dir" 2>/dev/null || true
/usr/bin/codesign "${codesign_flags[@]}" "$app_dir"
echo "$app_dir"
