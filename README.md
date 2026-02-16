# tree_content

Recursively prints all files in a directory in a structured format, including file contents.

Designed to generate full project context for LLM ingestion, code review, or archival — while safely excluding large, binary, or sensitive files.

---

## What It Does

- Recursively scans the current directory
- Prints each file with a clear header
- Outputs file contents (unless excluded)
- Excluded files are still shown, marked as `[not listed]`
- Skips hidden paths
- Skips files modified during execution
- Works on Linux and macOS

---

## Output Format

Included file:

```
=== relative/path/to/file ===
[file content]
```

Excluded file:

```
=== relative/path/to/file [not listed] ===
```

This preserves full project structure without dumping binaries or secrets.

---

# Installation

## Run Without Installing

```bash
wget -qO- https://example.com/tree_content.sh | bash
```

Pass arguments like this:

```bash
wget -qO- https://example.com/tree_content.sh | bash -s -- \
  --exclude="tests" \
  --output="context.txt"
```

---

## Install Globally (Recommended)

Install system-wide so you can use it anywhere:

```bash
sudo wget -qO /usr/bin/tree_content https://example.com/tree_content.sh \
  && sudo chmod +x /usr/bin/tree_content
```

Then simply run:

```bash
tree_content
```

### Alternative (curl)

```bash
sudo curl -fsSL https://example.com/tree_content.sh -o /usr/bin/tree_content \
  && sudo chmod +x /usr/bin/tree_content
```

### Uninstall

```bash
sudo rm /usr/bin/tree_content
```

---

# Usage

## Basic

```bash
tree_content
```

## Output to File

```bash
tree_content --output="context.txt"
```

## Add Custom Exclusions

```bash
tree_content --exclude="tests,migrations"
```

## Combine Options

```bash
tree_content --exclude="tests" --output="context.txt"
```

---

# Why This Is Useful for LLMs

- Provides complete project structure
- Avoids leaking secrets
- Avoids dumping media/binary files
- Avoids dependency folders
- Keeps prompt size reasonable

Typical workflow:

```bash
tree_content --output="context.txt"
```

Upload `context.txt` to your LLM and prompt it with full context.

---

# Requirements

- Bash
- find
- stat
- Linux or macOS

---

# Default Exclusions

These files are always excluded from content output but still listed as `[not listed]`.

## Archives
```
.tar .gz .zip .rar .7z .bz2
```

## Dependencies
```
node_modules
vendor
```

## Version Control
```
.git
.svn
```

## Environment / Secrets
```
.env
.env.*
secrets
credentials
.key
.pem
.crt
id_rsa
id_dsa
wp-config
```

## Build Output
```
dist
build
target
coverage
.next
.nuxt
.out
.cache
tmp
```

## Databases
```
.sqlite
.db
.sql
```

## IDE / System
```
.DS_Store
.idea
.vscode
Thumbs.db
```

## Media Files
```
.png .jpg .jpeg .gif .webp .svg
.mp4 .mov .avi .mkv
.mp3 .wav .ogg .flac
```

## Documents
```
.pdf .doc .docx .xls .xlsx .ppt .pptx
```

## Binaries
```
.exe .dll .so .dylib .bin .iso
```

---

# License

MIT
```
