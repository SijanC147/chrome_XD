#!/usr/bin/env bash
#
# Ensure a GitHub release exists for a tag, upload its assets, and publish it.
#
# A release this script creates starts life as a *draft* and is published only
# after every asset has uploaded, so an interrupted or failing run can never
# leave a visible release with missing downloads. A release that already
# exists (for example one created by hand in the GitHub UI) keeps its title,
# notes, and draft state; only its assets are refreshed.
#
# Assets are replaced by name, so re-running against the same tag is safe.
#
set -euo pipefail

DRY_RUN=false
TAG=""
VERSION=""
# Assets are tracked with an explicit counter so the array is never expanded
# while empty: bash 3.2 (the macOS system bash) treats "${arr[@]}" on an empty
# array as an unbound variable under 'set -u'.
ASSETS=()
ASSET_COUNT=0

usage() {
  cat <<'EOF'
Usage: publish-release.sh --tag <tag> [--version <version>] [--asset <path>]... [--dry-run]

Ensures a GitHub release exists for <tag>, uploads the given assets to it, and
publishes it if this invocation created it.

Options:
  --tag <tag>          Git tag the release belongs to (required)
  --version <version>  Version used in the generated release title
                       (default: <tag> with any leading 'v' removed)
  --asset <path>       File to attach; repeat for multiple assets
  --dry-run            Print the actions that would be taken. Creates,
                       uploads, deletes, and publishes nothing.
  -h, --help           Show this help

Required environment (unless --dry-run):
  GH_TOKEN             Token with contents: write on the repository
  GITHUB_REPOSITORY    owner/repo (set automatically by GitHub Actions)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --asset)
      ASSETS[ASSET_COUNT]="${2:-}"
      ASSET_COUNT=$((ASSET_COUNT + 1))
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

if [ -z "$TAG" ]; then
  echo "::error::publish-release.sh: --tag is required" >&2
  usage >&2
  exit 2
fi
VERSION="${VERSION:-${TAG#v}}"

if [ "$ASSET_COUNT" -eq 0 ]; then
  echo "::error::publish-release.sh: at least one --asset is required" >&2
  usage >&2
  exit 2
fi

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] would look for an existing release (published or draft) for tag '$TAG'"
  echo "[dry-run] if absent: would create a DRAFT release titled 'ChromeXD $VERSION' with generated notes"
  echo "[dry-run] if present: would leave its title, notes, and draft state untouched"
  for ASSET in "${ASSETS[@]}"; do
    if [ -e "$ASSET" ]; then
      echo "[dry-run] would upload asset '$(basename "$ASSET")' ($(wc -c < "$ASSET" | tr -d ' ') bytes), replacing any asset of the same name"
    else
      echo "[dry-run] would upload asset '$ASSET' (missing on disk — this would fail)"
    fi
  done
  echo "[dry-run] would publish the release only if this run created it"
  echo "[dry-run] nothing created, uploaded, deleted, or published"
  exit 0
fi

for ASSET in "${ASSETS[@]}"; do
  if [ ! -f "$ASSET" ]; then
    echo "::error::publish-release.sh: asset not found: $ASSET" >&2
    exit 1
  fi
done

: "${GH_TOKEN:?publish-release.sh: GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?publish-release.sh: GITHUB_REPOSITORY is required}"

API="https://api.github.com/repos/$GITHUB_REPOSITORY"
UPLOADS="https://uploads.github.com/repos/$GITHUB_REPOSITORY"

api() {
  local method="$1" url="$2"
  shift 2
  curl -sS -X "$method" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url" "$@"
}

# A published release can be fetched by tag, but the releases-by-tag endpoint
# never returns drafts — so fall back to scanning the release list. That also
# makes re-runs idempotent when an earlier attempt left a draft behind.
RELEASE_ID="$(api GET "$API/releases/tags/$TAG" | jq -r '.id // empty')"
if [ -z "$RELEASE_ID" ]; then
  RELEASE_ID="$(api GET "$API/releases?per_page=100" \
    | jq -r --arg tag "$TAG" 'map(select(.tag_name == $tag)) | .[0].id // empty')"
fi

CREATED_RELEASE=false
if [ -n "$RELEASE_ID" ]; then
  echo "Release for $TAG already exists (id $RELEASE_ID); leaving its title, notes, and draft state untouched."
else
  echo "Creating draft release for $TAG with an auto-generated changelog..."
  PAYLOAD="$(jq -n --arg tag "$TAG" --arg name "ChromeXD $VERSION" \
    '{tag_name: $tag, name: $name, generate_release_notes: true, draft: true, prerelease: false}')"
  RESPONSE="$(api POST "$API/releases" -d "$PAYLOAD")"
  RELEASE_ID="$(printf '%s' "$RESPONSE" | jq -r '.id // empty')"
  if [ -z "$RELEASE_ID" ]; then
    echo "::error::Failed to create release for $TAG: $(printf '%s' "$RESPONSE" | jq -c '{message, errors}')"
    exit 1
  fi
  CREATED_RELEASE=true
  echo "Created draft release $TAG (id $RELEASE_ID)."
fi

for ASSET in "${ASSETS[@]}"; do
  ASSET_NAME="$(basename "$ASSET")"

  EXISTING_ASSET_ID="$(api GET "$API/releases/$RELEASE_ID/assets?per_page=100" \
    | jq -r --arg name "$ASSET_NAME" 'map(select(.name == $name)) | .[0].id // empty')"
  if [ -n "$EXISTING_ASSET_ID" ]; then
    echo "Replacing existing asset $ASSET_NAME (id $EXISTING_ASSET_ID)..."
    api DELETE "$API/releases/assets/$EXISTING_ASSET_ID" > /dev/null
  fi

  echo "Uploading $ASSET_NAME..."
  UPLOAD_RESPONSE="$(api POST "$UPLOADS/releases/$RELEASE_ID/assets?name=$ASSET_NAME" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$ASSET")"
  UPLOAD_STATE="$(printf '%s' "$UPLOAD_RESPONSE" | jq -r '.state // empty')"
  if [ "$UPLOAD_STATE" != "uploaded" ]; then
    echo "::error::Failed to upload $ASSET_NAME: $(printf '%s' "$UPLOAD_RESPONSE" | jq -c '{message, errors, state}')"
    exit 1
  fi
  echo "Uploaded $ASSET_NAME ($(printf '%s' "$UPLOAD_RESPONSE" | jq -r '.size') bytes)."
done

if [ "$CREATED_RELEASE" = true ]; then
  echo "All assets uploaded; publishing release $TAG..."
  RESPONSE="$(api PATCH "$API/releases/$RELEASE_ID" -d '{"draft": false}')"
  if [ "$(printf '%s' "$RESPONSE" | jq -r '.draft')" != "false" ]; then
    echo "::error::Failed to publish release $TAG: $(printf '%s' "$RESPONSE" | jq -c '{message, errors, draft}')"
    exit 1
  fi
  echo "Published release: $(printf '%s' "$RESPONSE" | jq -r '.html_url')"
else
  echo "Release $TAG was not created by this run; leaving its draft state as-is."
fi
