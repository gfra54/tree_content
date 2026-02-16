# Tree Content

A shell script that recursively lists all files in a directory and prints their content in a structured format.

It is designed to generate a complete project context that can be fed into a Large Language Model (LLM) before prompting.

---

## Overview

The script:

- Recursively scans the current directory
- Prints each file using a clear header format
- Outputs file contents (unless excluded)
- Still prints excluded files, but marks them as `[not listed]`
- Skips hidden paths
- Skips files modified during execution
- Supports custom exclusions
- Can output to stdout or a file

---

## Output Format

For included files:

```
=== relative/path/to/file ===
[file content here]
```

For excluded files:

```
=== relative/path/to/file [not listed] ===
```

This preserves the project structure while protecting large, binary, or sensitive files.

---

## Features

- `--exclude="term1,term2"`  
  Add additional exclusion terms (CSV format).

- `--output="file.txt"`  
  Write output to a file instead of stdout.

- Built‑in exclusion rules for:
  - Archives
  - Dependencies
  - Version control
  - Secrets
  - Build artifacts
  - Media files
  - Documents
  - Binaries
  - Databases
  - IDE/system files

- Cross-platform compatible (Linux + macOS)

---

## Default Exclusions

The following are always excluded from content output (but still listed as `[not listed]`):

### Archives
```
.tar .gz .zip .rar .7z .bz2
```

### Dependencies
```
node_modules vendor
```

### Version Control
```
.git .svn
```

### Environment / Secrets
```
.env .env.*
secrets credentials
.key .pem .crt
id_rsa id_dsa
wp-config
```

### Build Output
```
dist build target coverage
.next .nuxt .out .cache
tmp
```

### Databases
```
.sqlite .db .sql
```

### IDE / System
```
.DS_Store .idea .vscode Thumbs.db
```

### Media Files
```
.png .jpg .jpeg .gif .webp .svg
.mp4 .mov .avi .mkv
.mp3 .wav .ogg .flac
```

### Documents
```
.pdf .doc .docx .xls .xlsx .ppt .pptx
```

### Binaries
```
.exe .dll .so .dylib .bin .iso
```

---

## Installation

Make the script executable:

```bash
chmod +x tree_content.sh
```

Run it:

```bash
./tree_content.sh
```

---

## Usage Examples

### Basic Usage

```bash
./tree_content.sh
```

Prints everything (except excluded content) to stdout.

---

### Output to a File

```bash
./tree_content.sh --output="project_dump.txt"
```

---

### Add Custom Exclusions

```bash
./tree_content.sh --exclude="tests,migrations"
```

---

### Combine Options

```bash
./tree_content.sh \
  --exclude="tests,migrations" \
  --output="context.txt"
```

---

## Using with wget (One‑Liner Execution)

You can download and execute the script directly:

```bash
wget -qO- https://example.com/tree_content.sh | bash
```

### Passing Parameters

When piping into bash, you must use `bash -s --`:

```bash
wget -qO- https://example.com/tree_content.sh | bash -s -- \
  --exclude="tests,migrations" \
  --output="context.txt"
```

Or using curl:

```bash
curl -fsSL https://example.com/tree_content.sh | bash -s -- \
  --exclude="tests,migrations"
```

Explanation:

- `-s` tells bash to read from stdin
- `--` separates bash options from script arguments
- Everything after `--` is passed to the script

---

## Recommended Workflow for LLM Usage

1. Run:

   ```bash
   ./tree_content.sh --output="context.txt"
   ```

2. Upload `context.txt` into your LLM.

3. Prompt:

   > Here is my project. Help me refactor X.

Because excluded files are still listed (but not dumped), the model understands full project structure without being polluted by binaries or secrets.

---

## Safety Notes

- Never remove `.env` or secret exclusions when sharing publicly.
- Be careful running this at filesystem root.
- Large projects may produce very large output files.
- Dependency folders should remain excluded for best results.

---

## Requirements

- Bash
- find
- stat
- Linux or macOS

---

## License

MIT
```
