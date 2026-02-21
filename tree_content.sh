#!/usr/bin/env bash

# ------------------------------------------------------------
# tree_content
#
# Recursively prints project files in structured format.
#
# Features:
#   --exclude="csv"
#   --include-only="csv"
#   --display-unlisted=true
#   --output="file"
#   --watch
#
# Safe by default:
#   - Skips hidden paths
#   - Skips modified-during-run files
#   - Excludes sensitive/binary/media files
#   - Verifies MIME is plain text
# ------------------------------------------------------------

set -euo pipefail

TARGET_DIR="."
USER_EXCLUDES=""
INCLUDE_ONLY=""
DISPLAY_UNLISTED="false"
OUTPUT_FILE=""
TMP_OUTPUT=""
WATCH_MODE="false"

# ------------------------------------------------------------
# Default Exclusions
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
    --include-only=*)
      INCLUDE_ONLY="${1#*=}"
      shift
      ;;
    --display-unlisted=*)
      DISPLAY_UNLISTED="${1#*=}"
      shift
      ;;
    --output=*)
      OUTPUT_FILE="${1#*=}"
      shift
      ;;
    --watch)
      WATCH_MODE="true"
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

TARGET_DIR="${TARGET_DIR%/}"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

csv_contains() {
  local value="$1"
  local csv="$2"

  [[ -z "$csv" ]] && return 1

  IFS=',' read -ra TERMS <<< "$csv"
  for t in "${TERMS[@]}"; do
    [[ -z "$t" ]] && continue
    [[ "$value" == *"$t"* ]] && return 0
  done
  return 1
}

should_print_unlisted() {
  [[ "$DISPLAY_UNLISTED" == "true" ]]
}

is_hidden() {
  [[ "$1" == */.* ]]
}

is_excluded_dir() {
  for dir in "${EXCLUDED_DIRS[@]}"; do
    [[ "$1" == *"/$dir/"* ]] && return 0
  done
  return 1
}

is_excluded_file() {
  local base
  base=$(basename "$1")
  for f in "${EXCLUDED_FILES[@]}"; do
    [[ "$base" == "$f" ]] && return 0
  done
  return 1
}

is_excluded_pattern() {
  for p in "${EXCLUDED_PATTERNS[@]}"; do
    [[ "$1" == *"$p"* ]] && return 0
  done

  csv_contains "$1" "$USER_EXCLUDES" && return 0
  return 1
}

is_excluded_extension() {
  local ext="${1##*.}"
  for e in "${EXCLUDED_EXTENSIONS[@]}"; do
    [[ "$ext" == "$e" ]] && return 0
  done
  return 1
}

is_plain_text() {
  local mime
  mime=$(file --mime-type -b "$1")

  case "$mime" in
    text/*|application/json|application/xml|application/javascript)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

print_unlisted() {
  local rel="$1"
  if should_print_unlisted; then
    echo "=== $rel [not listed] ==="
  fi
}

# ------------------------------------------------------------
# Core Runner
# ------------------------------------------------------------

run_tree() {

  START_TIME=$(date +%s)
  PRINTED_FILES=()

  if [[ -n "$OUTPUT_FILE" ]]; then
    TMP_OUTPUT=$(mktemp)
    exec > "$TMP_OUTPUT"
  fi

  while IFS= read -r file; do

    is_hidden "$file" && continue

    rel="${file#$TARGET_DIR/}"

    if is_excluded_dir "$file" ||
       is_excluded_file "$file" ||
       is_excluded_pattern "$file" ||
       is_excluded_extension "$file"; then

      print_unlisted "$rel"
      continue
    fi

    if ! is_plain_text "$file"; then
      print_unlisted "$rel"
      continue
    fi

    if [[ -n "$INCLUDE_ONLY" ]]; then
      if csv_contains "$file" "$INCLUDE_ONLY"; then
        echo "=== $rel ==="
        cat "$file"
        echo
        PRINTED_FILES+=("$file")
      else
        print_unlisted "$rel"
      fi
      continue
    fi

    echo "=== $rel ==="
    cat "$file"
    echo

    PRINTED_FILES+=("$file")

  done < <(find "$TARGET_DIR" -type f | sort)

  if [[ -n "$OUTPUT_FILE" ]]; then
    mv "$TMP_OUTPUT" "$OUTPUT_FILE"
    exec > /dev/tty
    echo "Output written to $OUTPUT_FILE"
  fi
}

# ------------------------------------------------------------
# Execution
# ------------------------------------------------------------

if [[ "$WATCH_MODE" != "true" ]]; then
  run_tree
else
  echo "Watch mode enabled. Press Ctrl+C to stop."
  echo

  while true; do
    clear
    run_tree

    echo
    echo "Waiting for changes..."

    if command -v inotifywait >/dev/null 2>&1; then
      inotifywait -e modify "${PRINTED_FILES[@]}" >/dev/null 2>&1
    elif command -v fswatch >/dev/null 2>&1; then
      fswatch -1 "${PRINTED_FILES[@]}" >/dev/null 2>&1
    else
      echo "Error: --watch requires inotifywait (Linux) or fswatch (macOS)"
      exit 1
    fi
  done
fi
