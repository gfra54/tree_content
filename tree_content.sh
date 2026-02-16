#!/usr/bin/env bash

# ------------------------------------------------------------
# tree_content
# Recursively prints file tree and file contents.
# Supports exclusion, inclusion filters, size limits,
# binary detection, and optional output file.
# ------------------------------------------------------------

set -euo pipefail

# -------------------------
# Default configuration
# -------------------------

TARGET_DIR="."
EXCLUDE_PATTERNS=""
INCLUDE_ONLY=""
MAX_SIZE=""
OUTPUT_FILE=""
TMP_OUTPUT=""

# -------------------------
# Usage function
# -------------------------

usage() {
  echo "Usage:"
  echo "  tree_content [directory] [options]"
  echo
  echo "Options:"
  echo "  --exclude=dir1,dir2        Comma-separated directories to exclude"
  echo "  --include-only=ext1,ext2   Only include file extensions (e.g. php,js)"
  echo "  --max-size=SIZE            Skip files larger than SIZE (e.g. 1M, 500K)"
  echo "  --output=FILE              Write output to FILE instead of stdout"
  exit 1
}

# -------------------------
# Parse arguments
# -------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclude=*)
      EXCLUDE_PATTERNS="${1#*=}"
      shift
      ;;
    --include-only=*)
      INCLUDE_ONLY="${1#*=}"
      shift
      ;;
    --max-size=*)
      MAX_SIZE="${1#*=}"
      shift
      ;;
    --output=*)
      OUTPUT_FILE="${1#*=}"
      shift
      ;;
    -*)
      usage
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

# -------------------------
# Validate directory
# -------------------------

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi

# -------------------------
# Build find command
# -------------------------

FIND_CMD=(find "$TARGET_DIR" -type f)

# Exclude directories
if [[ -n "$EXCLUDE_PATTERNS" ]]; then
  IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_PATTERNS"
  for pattern in "${EXCLUDES[@]}"; do
    FIND_CMD+=( ! -path "*/$pattern/*" )
  done
fi

# Include only extensions
if [[ -n "$INCLUDE_ONLY" ]]; then
  IFS=',' read -ra INCLUDES <<< "$INCLUDE_ONLY"
  FIND_CMD+=( \( )
  for i in "${!INCLUDES[@]}"; do
    ext="${INCLUDES[$i]}"
    if [[ $i -ne 0 ]]; then
      FIND_CMD+=( -o )
    fi
    FIND_CMD+=( -iname "*.$ext" )
  done
  FIND_CMD+=( \) )
fi

# Max size
if [[ -n "$MAX_SIZE" ]]; then
  FIND_CMD+=( -size "-$MAX_SIZE" )
fi

# -------------------------
# Prepare output
# -------------------------

if [[ -n "$OUTPUT_FILE" ]]; then
  TMP_OUTPUT=$(mktemp)
  exec > "$TMP_OUTPUT"
fi

# -------------------------
# Print directory tree
# -------------------------

echo "============================================================"
echo "DIRECTORY TREE"
echo "============================================================"
echo

tree -a "$TARGET_DIR" 2>/dev/null || echo "(tree command not installed)"

echo
echo "============================================================"
echo "FILE CONTENTS"
echo "============================================================"
echo

# -------------------------
# Process files
# -------------------------

while IFS= read -r file; do

  # Skip binary files
  if file --mime "$file" | grep -q binary; then
    continue
  fi

  echo "------------------------------------------------------------"
  echo "FILE: $file"
  echo "------------------------------------------------------------"
  echo

  cat "$file"
  echo
  echo

done < <("${FIND_CMD[@]}" | sort)

# -------------------------
# Finalize output
# -------------------------

if [[ -n "$OUTPUT_FILE" ]]; then
  mv "$TMP_OUTPUT" "$OUTPUT_FILE"
  echo "Output written to $OUTPUT_FILE"
fi
