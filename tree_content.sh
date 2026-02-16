#!/usr/bin/env bash

# ------------------------------------------------------------
# tree_content
# Recursively prints all files in a directory in structured format.
# Excluded files are shown as: === path [not listed] ===
# Skips hidden paths and files modified during execution.
# Ensures only plain-text files are printed.
# ------------------------------------------------------------

set -euo pipefail

START_TIME=$(date +%s)

TARGET_DIR="."
USER_EXCLUDES=""
OUTPUT_FILE=""
TMP_OUTPUT=""

# ------------------------------------------------------------
# Default Exclusions (must match README)
# ------------------------------------------------------------

EXCLUDED_DIRS=(
  node_modules vendor
  .git .svn
  dist build target coverage .next .nuxt .out .cache tmp
  .idea .vscode
)

EXCLUDED_FILES=(
  .DS_Store Thumbs.db
)

EXCLUDED_PATTERNS=(
  .env .env. secrets credentials
  .key .pem .crt id_rsa id_dsa wp-config
)

EXCLUDED_EXTENSIONS=(
  tar gz zip rar 7z bz2
  sqlite db sql
  png jpg jpeg gif webp svg
  mp4 mov avi mkv
  mp3 wav ogg flac
  pdf doc docx xls xlsx ppt pptx
  exe dll so dylib bin iso
)

# ------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclude=*)
      USER_EXCLUDES="${1#*=}"
      shift
      ;;
    --output=*)
      OUTPUT_FILE="${1#*=}"
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi

# Normalize directory path (remove trailing slash)
TARGET_DIR="${TARGET_DIR%/}"

# ------------------------------------------------------------
# Output Redirection
# ------------------------------------------------------------

if [[ -n "$OUTPUT_FILE" ]]; then
  TMP_OUTPUT=$(mktemp)
  exec > "$TMP_OUTPUT"
fi

# ------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------

is_hidden() {
  local path="$1"
  [[ "$path" == */.* ]]
}

is_excluded_dir() {
  local file="$1"
  for dir in "${EXCLUDED_DIRS[@]}"; do
    [[ "$file" == *"/$dir/"* ]] && return 0
  done
  return 1
}

is_excluded_file() {
  local file="$1"
  local base
  base=$(basename "$file")
  for f in "${EXCLUDED_FILES[@]}"; do
    [[ "$base" == "$f" ]] && return 0
  done
  return 1
}

is_excluded_pattern() {
  local file="$1"

  for p in "${EXCLUDED_PATTERNS[@]}"; do
    [[ "$file" == *"$p"* ]] && return 0
  done

  if [[ -n "$USER_EXCLUDES" ]]; then
    IFS=',' read -ra USER <<< "$USER_EXCLUDES"
    for u in "${USER[@]}"; do
      [[ "$file" == *"$u"* ]] && return 0
    done
  fi

  return 1
}

is_excluded_extension() {
  local file="$1"
  local ext="${file##*.}"
  for e in "${EXCLUDED_EXTENSIONS[@]}"; do
    [[ "$ext" == "$e" ]] && return 0
  done
  return 1
}

# Final safety layer: only allow plain-text files
is_plain_text() {
  local mime
  mime=$(file --mime-type -b "$1")

  case "$mime" in
    text/*)
      return 0
      ;;
    application/json)
      return 0
      ;;
    application/xml)
      return 0
      ;;
    application/javascript)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

was_modified_during_run() {
  local file="$1"
  local mod_time

  # Linux (GNU stat) or macOS (BSD stat)
  mod_time=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
  (( mod_time > START_TIME ))
}

# ------------------------------------------------------------
# Main Processing
# ------------------------------------------------------------

find "$TARGET_DIR" -type f | sort | while read -r file; do

  # Skip hidden paths
  if is_hidden "$file"; then
    continue
  fi

  # Skip files modified during execution
  if was_modified_during_run "$file"; then
    continue
  fi

  # Compute relative path
  rel="${file#$TARGET_DIR/}"
  [[ "$file" == "$TARGET_DIR" ]] && rel=$(basename "$file")

  # Hard exclusions
  if is_excluded_dir "$file" ||
     is_excluded_file "$file" ||
     is_excluded_pattern "$file" ||
     is_excluded_extension "$file"; then

    echo "=== $rel [not listed] ==="
    continue
  fi

  # MIME safety check
  if ! is_plain_text "$file"; then
    echo "=== $rel [not listed] ==="
    continue
  fi

  # Included file
  echo "=== $rel ==="
  cat "$file"
  echo

done

# ------------------------------------------------------------
# Finalize
# ------------------------------------------------------------

if [[ -n "$OUTPUT_FILE" ]]; then
  mv "$TMP_OUTPUT" "$OUTPUT_FILE"
  echo "Output written to $OUTPUT_FILE"
fi
