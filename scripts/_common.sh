# Shared by the scripts in this folder. Not run on its own.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/src"

if ! command -v fvm >/dev/null 2>&1; then
  echo "fvm isn't installed. Install it (https://fvm.app), then run: cd src && fvm install" >&2
  exit 1
fi

# The Flutter version pinned in src/.fvmrc.
flutter() { (cd "$APP" && fvm flutter "$@"); }

# This machine's desktop platform: macos, linux or windows.
host_platform() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    MINGW* | MSYS* | CYGWIN*) echo windows ;;
    *) echo "Unsupported system: $(uname -s)" >&2; exit 1 ;;
  esac
}
