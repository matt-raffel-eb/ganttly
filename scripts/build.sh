#!/usr/bin/env bash
# Builds a release app and says where it is.
#   scripts/build.sh            for this machine's platform
#   scripts/build.sh linux      for another desktop platform (each one builds only on its own OS)
source "$(dirname "$0")/_common.sh"

platform="${1:-$(host_platform)}"
flutter pub get
flutter build "$platform" --release

case "$platform" in
  macos) out="$APP/build/macos/Build/Products/Release/Ganttly.app" ;;
  linux) out="$APP/build/linux/$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')/release/bundle" ;;
  windows) out="$APP/build/windows/x64/runner/Release" ;;
esac
echo
echo "Built: $out"
[[ "$platform" == macos ]] && echo "Open it with: open \"$out\""
exit 0
