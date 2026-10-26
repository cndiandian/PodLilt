#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

# Apple's ticket service can temporarily drop connections, even after stapling.
# Keep validation mandatory, but allow transient failures to recover.
retry_ticket_operation() {
  local attempt exit_code
  for attempt in 1 2 3 4; do
    if "$@"; then
      return 0
    else
      exit_code=$?
    fi
    if (( attempt == 4 )); then
      echo "Ticket operation failed after $attempt attempts (exit $exit_code)." >&2
      return "$exit_code"
    fi
    echo "Ticket operation failed (exit $exit_code); retrying in $((attempt * 5)) seconds…" >&2
    sleep "$((attempt * 5))"
  done
}

: "${APP_VERSION:?APP_VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
: "${CODE_SIGN_IDENTITY:?CODE_SIGN_IDENTITY is required}"
: "${APP_STORE_CONNECT_API_KEY_PATH:?APP_STORE_CONNECT_API_KEY_PATH is required}"
: "${APP_STORE_CONNECT_API_KEY_ID:?APP_STORE_CONNECT_API_KEY_ID is required}"
: "${APP_STORE_CONNECT_API_ISSUER_ID:?APP_STORE_CONNECT_API_ISSUER_ID is required}"

if [[ ! "$APP_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
  echo "Invalid APP_VERSION: $APP_VERSION" >&2
  exit 1
fi

export APP_VERSION BUILD_NUMBER CODE_SIGN_IDENTITY
"$project_dir/scripts/build.sh"

app_path="$project_dir/dist/PodLilt.app"
submission_archive="$project_dir/dist/PodLilt-notarization.zip"
release_archive="$project_dir/dist/PodLilt-v${APP_VERSION}.zip"
checksum_file="$release_archive.sha256"
notary_result="$(mktemp -t podlilt-notary-result).json"
trap 'rm -f "$notary_result"' EXIT

/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
rm -f "$submission_archive" "$release_archive" "$checksum_file"
/usr/bin/ditto -c -k --keepParent --sequesterRsrc "$app_path" "$submission_archive"

/usr/bin/xcrun notarytool submit "$submission_archive" \
  --key "$APP_STORE_CONNECT_API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
  --wait --output-format json > "$notary_result"

notary_status="$(/usr/bin/plutil -extract status raw -o - "$notary_result")"
submission_id="$(/usr/bin/plutil -extract id raw -o - "$notary_result")"
if [[ "$notary_status" != "Accepted" ]]; then
  echo "Notarization failed with status: $notary_status" >&2
  /usr/bin/xcrun notarytool log "$submission_id" \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" || true
  exit 1
fi

retry_ticket_operation /usr/bin/xcrun stapler staple "$app_path"
retry_ticket_operation /usr/bin/xcrun stapler validate "$app_path"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
/usr/sbin/spctl --assess --type execute --verbose=2 "$app_path"

/usr/bin/ditto -c -k --keepParent --sequesterRsrc "$app_path" "$release_archive"
(
  cd "${release_archive:h}"
  /usr/bin/shasum -a 256 "${release_archive:t}" > "${checksum_file:t}"
)

echo "$release_archive"
echo "$checksum_file"

dmg_path="$project_dir/dist/PodLilt-v${APP_VERSION}.dmg"
dmg_stage="$(mktemp -d -t podlilt-dmg)"
trap 'rm -f "$notary_result"; rm -rf "$dmg_stage"' EXIT
/usr/bin/ditto "$app_path" "$dmg_stage/PodLilt.app"
ln -s /Applications "$dmg_stage/Applications"
/usr/bin/hdiutil create -volname PodLilt -srcfolder "$dmg_stage" -ov -format UDZO "$dmg_path"
/usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$dmg_path"
/usr/bin/xcrun notarytool submit "$dmg_path" \
  --key "$APP_STORE_CONNECT_API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
  --wait --output-format json > "$notary_result"
[[ "$(/usr/bin/plutil -extract status raw -o - "$notary_result")" == "Accepted" ]] || exit 1
retry_ticket_operation /usr/bin/xcrun stapler staple "$dmg_path"
retry_ticket_operation /usr/bin/xcrun stapler validate "$dmg_path"
(
  cd "${dmg_path:h}"
  /usr/bin/shasum -a 256 "${dmg_path:t}" > "${dmg_path:t}.sha256"
)
