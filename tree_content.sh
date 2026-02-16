#!/bin/bash

#
# tree_content
#
# Recursively lists files and prints their contents.
# Excluded files are still listed but marked as [not listed].
#
# Features:
# - Supports --exclude="term1,term2"
# - Supports --output="file"
# - Hardcoded exclusions for binary, media, archives, secrets, build artifacts
# - Hidden files excluded
# - Files modified during execution excluded
# - Cross-platform stat support (Linux/macOS)
#

START_TIME=$(date +%s)

USER_EXCLUDE_PARAM=""
OUTPUT_FILE=""

# Comprehensive exclusion list
ALWAYS_EXCLUDED=(
    # Archives
    ".tar" ".gz" ".zip" ".rar" ".7z" ".bz2"

    # Dependencies
    "node_modules" "vendor"

    # VCS
    ".git" ".svn"

    # Environment / secrets
    ".env" ".env." "secrets" "credentials"
    ".key" ".pem" ".crt"
    "id_rsa" "id_dsa"
    "wp-config"

    # Build output
    "dist" "build" "target" "coverage"
    ".next" ".nuxt" ".out" ".cache"
    "tmp"

    # Databases
    ".sqlite" ".db" ".sql"

    # IDE / system
    ".DS_Store" ".idea" ".vscode" "Thumbs.db"

    # Media files
    ".png" ".jpg" ".jpeg" ".gif" ".webp" ".svg"
    ".mp4" ".mov" ".avi" ".mkv" ".mp3" ".wav"
    ".ogg" ".flac"

    # Documents
    ".pdf" ".doc" ".docx" ".xls" ".xlsx" ".ppt" ".pptx"

    # Binaries
    ".exe" ".dll" ".so" ".dylib" ".bin" ".iso"
)

# Parse arguments
for arg in "$@"; do
    case $arg in
        --exclude=*)
            USER_EXCLUDE_PARAM="${arg#*=}"
            shift
            ;;
        --output=*)
            OUTPUT_FILE="${arg#*=}"
            shift
            ;;
    esac
done

IFS=',' read -r -a USER_EXCLUDED <<< "$USER_EXCLUDE_PARAM"

EXCLUDE_TERMS=("${ALWAYS_EXCLUDED[@]}" "${USER_EXCLUDED[@]}")

# Initialize output file if provided
if [[ -n "$OUTPUT_FILE" ]]; then
    > "$OUTPUT_FILE"
fi

write_output() {
    local content="$1"

    if [[ -n "$OUTPUT_FILE" ]]; then
        echo -e "$content" >> "$OUTPUT_FILE"
    else
        echo -e "$content"
    fi
}

should_exclude() {
    local path="$1"

    for term in "${EXCLUDE_TERMS[@]}"; do
        [[ -z "$term" ]] && continue
        if [[ "$path" == *"$term"* ]]; then
            return 0
        fi
    done

    return 1
}

process_file() {
    local file_path="$1"
    local relative_path="${file_path#./}"

    if [[ "$file_path" == ./* ]]; then
        file_path="${file_path#./}"
    fi

    # Skip the script itself if needed
    if [[ "$file_path" == "bin/tree_content" ]]; then
        return
    fi

    if [[ ! -f "$file_path" ]]; then
        return
    fi

    # Check modification time
    FILE_TIME=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null)
    if [[ "$FILE_TIME" -ge "$START_TIME" ]]; then
        return
    fi

    # If excluded, print marker only
    if should_exclude "$file_path"; then
        write_output "=== $relative_path [not listed] ==="
        return
    fi

    # Print full content
    write_output "=== $relative_path ==="

    if [[ -n "$OUTPUT_FILE" ]]; then
        cat "$file_path" >> "$OUTPUT_FILE"
        echo >> "$OUTPUT_FILE"
    else
        cat "$file_path"
        echo
    fi
}

export -f process_file
export -f should_exclude
export -f write_output
export START_TIME
export EXCLUDE_TERMS
export OUTPUT_FILE

find . -type f \
    -not -path '*/.*' \
    -not -path '*/_*' \
    -exec bash -c 'process_file "$0"' {} \;
