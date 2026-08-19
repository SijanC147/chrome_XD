#!/usr/bin/env bash
#
# Build a distributable disk image containing an app bundle plus the customary
# drag-to-install /Applications symlink, and optionally code-sign the image.
#
# The app should already be signed (and notarized/stapled, for release builds)
# before it is placed in the image: the image seals whatever it is given.
#
set -euo pipefail

DRY_RUN=false
APP_PATH=""
OUTPUT_PATH=""
VOLUME_NAME=""
SIGN_IDENTITY=""

usage() {
  cat <<'EOF'
Usage: make-dmg.sh --app <path.app> --output <path.dmg> [options]

Creates a compressed (UDZO) disk image containing <path.app> and a symlink to
/Applications, so users can drag the app across to install it.

Options:
  --app <path.app>       Application bundle to package (required)
  --output <path.dmg>    Disk image to write; overwritten if present (required)
  --volname <name>       Mounted volume name (default: the app's base name)
  --sign <identity>      Code-sign the finished image with this identity.
                         Omit or pass '-' to leave the image unsigned.
  --dry-run              Print the actions that would be taken. Creates,
                         overwrites, and signs nothing.
  -h, --help             Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --volname)
      VOLUME_NAME="${2:-}"
      shift 2
      ;;
    --sign)
      SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$APP_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
  echo "::error::make-dmg.sh: --app and --output are required" >&2
  usage >&2
  exit 2
fi

APP_NAME="$(basename "$APP_PATH")"
VOLUME_NAME="${VOLUME_NAME:-${APP_NAME%.app}}"
STAGE_DIR="${RUNNER_TEMP:-/tmp}/dmg-stage-$$"

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] would stage '$APP_PATH' and an /Applications symlink in '$STAGE_DIR'"
  echo "[dry-run] would create UDZO disk image '$OUTPUT_PATH' (volume '$VOLUME_NAME')"
  if [ -e "$OUTPUT_PATH" ]; then
    echo "[dry-run] note: '$OUTPUT_PATH' already exists and would be overwritten"
  fi
  if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    echo "[dry-run] would code-sign the image with identity '$SIGN_IDENTITY'"
  else
    echo "[dry-run] would leave the image unsigned"
  fi
  echo "[dry-run] nothing created, overwritten, or signed"
  exit 0
fi

if [ ! -d "$APP_PATH" ]; then
  echo "::error::make-dmg.sh: app bundle not found: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
trap 'rm -rf "$STAGE_DIR"' EXIT

# ditto preserves bundle metadata, extended attributes, and any stapled ticket.
ditto "$APP_PATH" "$STAGE_DIR/$APP_NAME"
ln -s /Applications "$STAGE_DIR/Applications"

echo "Creating disk image $OUTPUT_PATH (volume '$VOLUME_NAME')..."
rm -f "$OUTPUT_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$OUTPUT_PATH"

if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
  echo "Code-signing $OUTPUT_PATH..."
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$OUTPUT_PATH"
  codesign --verify --verbose=2 "$OUTPUT_PATH"
else
  echo "Leaving $OUTPUT_PATH unsigned (no signing identity supplied)."
fi

hdiutil imageinfo "$OUTPUT_PATH" | grep -E '^(Format|Checksum Type):' || true
