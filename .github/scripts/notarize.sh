#!/usr/bin/env bash
#
# Submit a macOS distribution artifact to Apple's notary service, wait for the
# verdict, and staple the resulting ticket.
#
# Notarization tickets attach to the *bundle or disk image*, not to a zip
# archive, so the submitted file and the staple target can differ:
#   - .app delivered in a zip: submit the zip, staple the .app
#   - .dmg:                    submit the .dmg, staple the .dmg
#
set -euo pipefail

DRY_RUN=false
SUBMIT_PATH=""
STAPLE_PATH=""

usage() {
  cat <<'EOF'
Usage: notarize.sh --submit <file> [--staple <path>] [--dry-run]

Submits <file> (.zip or .dmg) to Apple's notary service, waits for the result,
and staples the ticket to <path>.

Options:
  --submit <file>   Archive or disk image to upload for notarization (required)
  --staple <path>   Bundle or disk image to staple the ticket to
                    (default: the --submit value)
  --dry-run         Print the actions that would be taken. Submits nothing and
                    modifies nothing on disk.
  -h, --help        Show this help

Required environment (unless --dry-run):
  NOTARY_API_KEY_P8      App Store Connect API private key contents (.p8)
  NOTARY_API_KEY_ID      App Store Connect API Key ID
  NOTARY_API_ISSUER_ID   App Store Connect API Issuer ID
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --submit)
      SUBMIT_PATH="${2:-}"
      shift 2
      ;;
    --staple)
      STAPLE_PATH="${2:-}"
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

if [ -z "$SUBMIT_PATH" ]; then
  echo "::error::notarize.sh: --submit is required" >&2
  usage >&2
  exit 2
fi
STAPLE_PATH="${STAPLE_PATH:-$SUBMIT_PATH}"

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] would submit '$SUBMIT_PATH' to notarytool and wait for the verdict"
  echo "[dry-run] would staple the ticket to '$STAPLE_PATH' and validate it"
  echo "[dry-run] nothing submitted, no files modified"
  exit 0
fi

for PATH_TO_CHECK in "$SUBMIT_PATH" "$STAPLE_PATH"; do
  if [ ! -e "$PATH_TO_CHECK" ]; then
    echo "::error::notarize.sh: path not found: $PATH_TO_CHECK" >&2
    exit 1
  fi
done

: "${NOTARY_API_KEY_P8:?notarize.sh: NOTARY_API_KEY_P8 is required}"
: "${NOTARY_API_KEY_ID:?notarize.sh: NOTARY_API_KEY_ID is required}"
: "${NOTARY_API_ISSUER_ID:?notarize.sh: NOTARY_API_ISSUER_ID is required}"

KEY_PATH="$(mktemp "${RUNNER_TEMP:-/tmp}/notary-key.XXXXXX")"
trap 'rm -f "$KEY_PATH"' EXIT
printf '%s' "$NOTARY_API_KEY_P8" > "$KEY_PATH"

echo "Submitting $SUBMIT_PATH for notarization..."
SUBMIT_JSON="$(xcrun notarytool submit "$SUBMIT_PATH" \
  --key "$KEY_PATH" \
  --key-id "$NOTARY_API_KEY_ID" \
  --issuer "$NOTARY_API_ISSUER_ID" \
  --wait --output-format json)"
echo "$SUBMIT_JSON"

STATUS="$(printf '%s' "$SUBMIT_JSON" | jq -r '.status')"
SUBMISSION_ID="$(printf '%s' "$SUBMIT_JSON" | jq -r '.id')"

if [ "$STATUS" != "Accepted" ]; then
  echo "::error::Notarization of $SUBMIT_PATH failed with status '$STATUS'. Notary log follows."
  xcrun notarytool log "$SUBMISSION_ID" \
    --key "$KEY_PATH" \
    --key-id "$NOTARY_API_KEY_ID" \
    --issuer "$NOTARY_API_ISSUER_ID" || true
  exit 1
fi

echo "Stapling notarization ticket to $STAPLE_PATH..."
xcrun stapler staple "$STAPLE_PATH"
xcrun stapler validate "$STAPLE_PATH"
