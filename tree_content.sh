#!/usr/bin/env bash

# ------------------------------------------------------------
# tree_content
#
# Recursively prints project files in structured format.
#
# Features:
#   --exclude="foo"      (can be used multiple times)
#   --include-only="csv"
#   --display-unlisted=true
#   --output="file"
#
# Safe by default:
#   - Skips hidden paths
#   - Skips modified-during-run files
#   - Excludes sensitive/binary/media files
#   - Verifies MIME is plain text
# ------------------------------------------------------------

set -euo pipefail

START_TIME=$(date +%s)

TARGET_DIR="."
INCLUDE_ONLY=""
DISPLAY_UNLISTED="false"
OUTPUT_FILE=""
TMP_OUTPUT=""

# ✅ accumulate multiple excludes
USER_EXCLUDES=()

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
  composer.lock
  package-lock.json
  yarn.lock
  pnpm-lock.yaml
  bun.lockb
)

EXCLUDED_PATTERNS=(
  .env .env. secrets credentials
  .key .pem .crt id_rsa id_dsa wp-config
)

EXCLUDED_EXTENSIONS=(
  # archives
  tar gz zip rar 7z bz2

  # databases
  sqlite db sql

  # images
  png jpg jpeg gif webp svg

  # video
  mp4 mov avi mkv

  # audio
  mp3 wav ogg flac

  # documents
  pdf doc docx

  # ✅ data files
  csv tsv xls xlsx ods numbers

  # binaries
  exe dll so dylib bin iso
)

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

print_help() {
cat << 'EOF'

tree_content
============

Recursively prints project files in a structured format.

By default this script:
  • Skips hidden files and directories
  • Skips common build/vendor/cache folders
  • Skips binaries, media, archives, databases
  • Skips sensitive files (.env, keys, credentials, etc.)
  • Skips files modified during execution
  • Prints only verified plain-text files


USAGE
-----

  tree_content [directory] [options]


ARGUMENTS
---------

  directory
      Target directory to scan.
      Default: current directory (.)

OPTIONS
-------

  --exclude="pattern"
      Exclude paths containing this pattern.
      Can be used multiple times.

      Example:
        tree_content . --exclude="tests" --exclude="migrations"


  --include-only="csv"
      Only print files whose path contains one of the
      comma-separated values.

      Example:
        tree_content . --include-only="controller,service"


  --display-unlisted=true
      Displays skipped files as:
        === path/to/file [not listed] ===

      Useful for debugging filters.

      Example:
        tree_content . --display-unlisted=true


  --output="file"
      Write output to a file instead of stdout.

      Example:
        tree_content . --output="project.txt"


  -h, --help
      Display this help message and exit.


EXAMPLES
--------

  1) Print everything (safe defaults):
     tree_content

  2) Scan specific directory:
     tree_content ./src

  3) Exclude additional directories:
     tree_content . --exclude="tests" --exclude="docs"

  4) Only include specific file types or names:
     tree_content . --include-only="controller,service,config"

  5) Show skipped files:
     tree_content . --display-unlisted=true

  6) Export result:
     tree_content . --output="snapshot.txt"

  7) Combine filters:
     tree_content ./app \
       --exclude="tests" \
       --include-only="controller,service" \
       --display-unlisted=true \
       --output="filtered.txt"


NOTES
-----

• Multiple --exclude flags are supported.
• --include-only matches substrings in full file path.
• CSV values must be comma-separated without spaces.
• Only plain text MIME types are printed.
• Designed for safe project introspection.


EOF
}

# ------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --exclude=*)
      USER_EXCLUDES+=("${1#*=}")
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
    -*)
      echo "Unknown option: $1"
      echo "Use --help to see available options."
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
# Output Redirection
# ------------------------------------------------------------

if [[ -n "$OUTPUT_FILE" ]]; then
  TMP_OUTPUT=$(mktemp)
  exec > "$TMP_OUTPUT"
fi

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
  local path="$1"

  for p in "${EXCLUDED_PATTERNS[@]}"; do
    [[ "$path" == *"$p"* ]] && return 0
  done

  # ✅ accumulated user excludes
  for ex in "${USER_EXCLUDES[@]}"; do
    [[ -z "$ex" ]] && continue
    [[ "$path" == *"$ex"* ]] && return 0
  done

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

was_modified_during_run() {
  local mod_time
  mod_time=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1")
  (( mod_time > START_TIME ))
}

print_unlisted() {
  local rel="$1"
  if should_print_unlisted; then
    echo "=== $rel [not listed] ==="
  fi
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

find "$TARGET_DIR" -type f | sort | while read -r file; do

  is_hidden "$file" && continue
  was_modified_during_run "$file" && continue

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
    else
      print_unlisted "$rel"
    fi
    continue
  fi

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
