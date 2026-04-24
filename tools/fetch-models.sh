#!/usr/bin/env bash
# tools/fetch-models.sh — idempotent CoreML model bootstrap.
#
# Reads tools/models.manifest and ensures every listed bundle is present on
# disk. Cache hits are decided by a <dest>/.fetch-models.sha256 sidecar
# marker whose content is the expected tarball SHA-256. Misses download the
# asset from its GitHub Release, SHA-verify the tarball, extract in place,
# and write the marker.
#
# The installed directory itself is NOT rehashed — `tar czf -` is
# non-deterministic on macOS because gzip embeds a timestamp in its header,
# so a recompute-based check would force a redownload on every run. The
# marker is the source of truth for "which version is installed".
#
# Used by:
#   - CI (.github/workflows/ci.yml) before swift build / xcodebuild.
#   - Xcode (Run Script Build Phase on the Mora app target) before sources compile.
#   - Developers, once after `git clone`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/tools/models.manifest"
# Repo that hosts the model releases. Override with FETCH_MODELS_REPO_SLUG to
# pull from a fork that publishes its own assets; the default is correct for
# plain clones of the upstream repo.
REPO_SLUG="${FETCH_MODELS_REPO_SLUG:-youtalk/mora}"
MARKER_NAME=".fetch-models.sha256"

if [[ ! -f "$MANIFEST" ]]; then
  echo "fetch-models: manifest not found at $MANIFEST" >&2
  exit 1
fi

# download_asset <tag> <asset> <out_path>
# Prefers gh (works in CI with GITHUB_TOKEN, clearer errors); falls back to curl.
download_asset() {
  local tag="$1" asset="$2" out="$3"
  if command -v gh >/dev/null 2>&1; then
    if gh release download "$tag" \
      --repo "$REPO_SLUG" \
      --pattern "$asset" \
      --output "$out" \
      --clobber; then
      return 0
    fi
    echo "fetch-models: gh download failed for $asset@$tag; falling back to curl" >&2
  fi
  local url="https://github.com/$REPO_SLUG/releases/download/$tag/$asset"
  if ! curl --fail --location --silent --show-error --output "$out" "$url"; then
    echo "fetch-models: curl failed for $url" >&2
    return 1
  fi
}

# verify_sha256 <file> <expected_sha>
verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "fetch-models: SHA-256 mismatch for $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
}

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip blank + comment lines.
  trimmed="${line#"${line%%[![:space:]]*}"}"
  [[ -z "$trimmed" ]] && continue
  [[ "$trimmed" == \#* ]] && continue

  # Columns: dest tag asset expected_sha
  # shellcheck disable=SC2086
  read -r dest tag asset expected_sha <<<"$line"
  if [[ -z "${dest:-}" || -z "${tag:-}" || -z "${asset:-}" || -z "${expected_sha:-}" ]]; then
    echo "fetch-models: malformed manifest line: $line" >&2
    exit 1
  fi

  abs_dest="$REPO_ROOT/$dest"
  marker="$abs_dest/$MARKER_NAME"
  parent_dir="$(dirname "$abs_dest")"

  if [[ -d "$abs_dest" && -f "$marker" ]]; then
    current="$(cat "$marker")"
    if [[ "$current" == "$expected_sha" ]]; then
      echo "fetch-models: $dest is up to date"
      continue
    fi
  fi

  echo "fetch-models: fetching $asset from $tag -> $dest"
  mkdir -p "$parent_dir"
  tmp="$(mktemp -t fetch-models.XXXXXX)"
  trap 'rm -f "$tmp"' EXIT

  if ! download_asset "$tag" "$asset" "$tmp"; then
    echo "fetch-models: download failed for $asset@$tag" >&2
    exit 1
  fi
  verify_sha256 "$tmp" "$expected_sha"

  rm -rf "$abs_dest"
  tar xzf "$tmp" -C "$parent_dir"

  if [[ ! -d "$abs_dest" ]]; then
    echo "fetch-models: expected $abs_dest after extracting $asset but it is missing" >&2
    exit 1
  fi

  printf '%s' "$expected_sha" >"$marker"
  rm -f "$tmp"
  trap - EXIT

  echo "fetch-models: installed $dest"
done <"$MANIFEST"
