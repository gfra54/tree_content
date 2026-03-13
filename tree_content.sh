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
  tar gz zip rar 7z bz2
  sqlite db sql
  png jpg jpeg gif webp svg
  mp4 mov avi mkv
  mp3 wav ogg flac
  pdf doc docx
  csv tsv xls xlsx ods numbers
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
  • Skips binaries, media, archives and databases
  • Skips files modified during execution
  • Only prints plain text files

Usage
-----

tree_content [options]

Options
-------

--exclude="pattern"
    Exclude anything containing this string in its path.
    Can be used multiple times.

--include-only="a,b,c"
    Only print files whose path contains one of the terms.

--display-unlisted=true
    Show placeholders for excluded files.

--output="file"
    Write output to a file instead of stdout.

--help
    Show this help.

Examples
--------

Exclude json and backups:

  tree_content --exclude="json" --exclude="backups"

Only include PHP files:

  tree_content --include-only="php"

Export project snapshot:

  tree_content --output="project.txt"

EOF
}

# ------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------

for arg in "$@"; do
  case $arg in
    --exclude=*)
      USER_EXCLUDES+=("${arg#*=}")
      ;;
    --include-only=*)
      INCLUDE_ONLY="${arg#*=}"
      ;;
    --display-unlisted=*)
      DISPLAY_UNLISTED="${arg#*=}"
      ;;
    --output=*)
      OUTPUT_FILE="${arg#*=}"
      ;;
    --help)
      print_help
      exit 0
      ;;
  esac
done

if [[ -n "$OUTPUT_FILE" ]]; then
  TMP_OUTPUT=$(mktemp)
  exec > "$TMP_OUTPUT"
fi

# ------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------

csv_contains() {
  local value="$1"
  local csv="$2"
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
  [[ "$(basename "$1")" == .* ]]
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
# Build find prune rules
# ------------------------------------------------------------

PRUNE_ARGS=()

for dir in "${EXCLUDED_DIRS[@]}"; do
  PRUNE_ARGS+=( -path "*/$dir" -o -path "*/$dir/*" -o )
done

for ex in "${USER_EXCLUDES[@]}"; do
  PRUNE_ARGS+=( -path "*$ex*" -o )
done

if [[ ${#PRUNE_ARGS[@]} -gt 0 ]]; then
  unset 'PRUNE_ARGS[${#PRUNE_ARGS[@]}-1]'
fi

# ------------------------------------------------------------
# Build text tree of directory structure
# ------------------------------------------------------------

build_tree() {
  local dir="$1"
  local prefix="$2"

  local entries=()
  while IFS= read -r entry; do
    local base
    base=$(basename "$entry")

    # Skip hidden
    [[ "$base" == .* ]] && continue

    # Skip excluded dirs
    local skip=0
    for exdir in "${EXCLUDED_DIRS[@]}"; do
      [[ "$base" == "$exdir" ]] && skip=1 && break
    done
    for ex in "${USER_EXCLUDES[@]}"; do
      [[ "$entry" == *"$ex"* ]] && skip=1 && break
    done
    [[ $skip -eq 1 ]] && continue

    entries+=("$entry")
  done < <(find "$dir" -maxdepth 1 -mindepth 1 | sort)

  local count=${#entries[@]}
  local i=0

  for entry in "${entries[@]}"; do
    i=$(( i + 1 ))
    local base
    base=$(basename "$entry")

    local connector="├── "
    local sub_prefix="${prefix}│   "
    if [[ $i -eq $count ]]; then
      connector="└── "
      sub_prefix="${prefix}    "
    fi

    if [[ -d "$entry" ]]; then
      echo "${prefix}${connector}${base}/"
      build_tree "$entry" "$sub_prefix"
    else
      echo "${prefix}${connector}${base}"
    fi
  done
}

# ------------------------------------------------------------
# LLM Preamble + Directory Tree
# ------------------------------------------------------------

print_preamble() {
  local abs_path
  abs_path=$(cd "$TARGET_DIR" && pwd)
  local generated_at
  generated_at=$(date '+%Y-%m-%d %H:%M:%S')

  cat << PREAMBLE
================================================================
LLM CONTEXT HEADER
================================================================

This file was automatically generated by the tree_content script.
It is intended to give a language model (LLM) a full, structured
snapshot of a software project so it can reason about the code,
answer questions, suggest improvements, or assist with debugging.

Generated at : $generated_at
Project root : $abs_path
Include only : ${INCLUDE_ONLY:-"(all plain-text files)"}
Display unlisted : $DISPLAY_UNLISTED

HOW THIS FILE IS ORGANIZED
---------------------------
1. This preamble — context for the LLM.
2. A text tree showing the full directory structure of the project,
   including folders and files that may not have been included in
   the content dump (e.g. binaries, excluded dirs, etc.).
3. The full content of every eligible plain-text file, each
   preceded by a header line of the form:
       === relative/path/to/file ===
   Files that were skipped (binary, excluded, sensitive, etc.)
   may appear as:
       === relative/path/to/file [not listed] ===
   if --display-unlisted=true was passed.

WHAT THE LLM SHOULD KNOW
--------------------------
- Hidden files and directories (starting with a dot) are skipped.
- Common build/vendor/cache directories are excluded by default:
  node_modules, vendor, .git, dist, build, target, .cache, tmp, etc.
- Binary, media, archive, and database files are never included.
- Sensitive files (.env, .key, .pem, credentials, etc.) are excluded.
- Only files whose MIME type is plain text are printed.
- Files modified during execution are skipped to avoid partial reads.

================================================================
DIRECTORY TREE
================================================================

$(basename "$abs_path")/
$(build_tree "$TARGET_DIR" "")

================================================================
FILE CONTENTS
================================================================

PREAMBLE
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

print_preamble

if [[ ${#PRUNE_ARGS[@]} -gt 0 ]]; then
  FIND_CMD=(find "$TARGET_DIR" \( "${PRUNE_ARGS[@]}" \) -prune -o -type f -print)
else
  FIND_CMD=(find "$TARGET_DIR" -type f)
fi

"${FIND_CMD[@]}" | sort | while read -r file; do

  # ----------------------------------------------------------
  # HARD USER EXCLUDE (highest priority)
  # ----------------------------------------------------------

  for ex in "${USER_EXCLUDES[@]}"; do
    [[ "$file" == *"$ex"* ]] && continue 2
  done

  is_hidden "$file" && continue
  was_modified_during_run "$file" && continue

  rel="${file#$TARGET_DIR/}"

  if is_excluded_file "$file" ||
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
  echo "Output written to $OUTPUT_FILE" >&2
fi
