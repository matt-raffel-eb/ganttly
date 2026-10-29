#!/usr/bin/env bash
# Runs Ganttly from source (debug, with hot reload in the terminal: r reload, R restart, q quit).
#   scripts/run.sh            on this machine's platform
#   scripts/run.sh linux      on another desktop platform (macos, windows, linux)
source "$(dirname "$0")/_common.sh"

platform="${1:-$(host_platform)}"
flutter pub get
flutter run -d "$platform"
