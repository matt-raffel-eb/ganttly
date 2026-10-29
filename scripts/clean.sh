#!/usr/bin/env bash
# Deletes build output and cached packages, for when a build gets into a strange state.
source "$(dirname "$0")/_common.sh"

flutter clean
flutter pub get
