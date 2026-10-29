#!/usr/bin/env bash
# Checks the code: static analysis, then every test.
#   scripts/test.sh                          all tests
#   scripts/test.sh test/engine              one folder or file
source "$(dirname "$0")/_common.sh"

flutter pub get
flutter analyze
flutter test "$@"
