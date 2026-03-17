# tree_content

Recursively prints all files in a directory in a structured format, including file contents.

Designed to generate full project context for LLM ingestion, code review, or archival — while safely excluding large, binary, or sensitive files.

---

## What It Does

- Recursively scans the current directory
- Prints each file with a clear header
- Outputs file contents (unless excluded)
- Excluded files are still shown, marked as `[not listed]` (with `--display-unlisted=true`)
- Skips hidden paths
- Skips files modified during execution
- Verifies MIME type to ensure only plain-text files are included
- Works on Linux and macOS

---

## Output Format

Included file:

```
=== relative/path/to/file ===
[file content]
```

Excluded file (when `--display-unlisted=true`):

```
=== relative/path/to/file [not listed] ===
```

This preserves full project structure without dumping binaries or secrets.

---

## Installation

### Run Without Installing

```bash
wget -qO- https://github.com/gfra54/tree_content/raw/refs/heads/main/tree_content.sh | bash
```

Pass arguments like this:

```bash
wget -qO- https://github.com/gfra54/tree_content/raw/refs/heads/main/tree_content.sh | bash -s -- 
  --exclude="tests" \
  --output="context.txt"
```

---

### Install Globally (Recommended)

Install system-wide so you can use it anywhere:

```bash
sudo wget -qO /usr/bin/tree_content https://github.com/gfra54/tree_content/raw/refs/heads/main/tree_content.sh \
  && sudo chmod +x /usr/bin/tree_content
```

Then simply run:

```bash
tree_content
```

#### Alternative (curl)

```bash
sudo curl -fsSL https://github.com/gfra54/tree_content/raw/refs/heads/main/tree_content.sh -o /usr/bin/tree_content \
  && sudo chmod +x /usr/bin/tree_content
```

#### Uninstall

```bash
sudo rm /usr/bin/tree_content
```

---

## Usage

### Basic

```bash
tree_content
```

### Output to File

```bash
tree_content --output="context.txt"
```

### Add Custom Exclusions

```bash
tree_content --exclude="tests" --exclude="migrations"
```

Or with comma-separated values:

```bash
tree_content --exclude="tests,migrations,fixtures"
```

### Include Only Specific Files

Only print files matching certain patterns:

```bash
tree_content --include-only="src,lib"
```

Comma-separated patterns work here too.

### Display Excluded Files as Placeholders

Show which files were excluded but not their contents:

```bash
tree_content --display-unlisted=true
```

### Combine Options

```bash
tree_content \
  --exclude="tests" \
  --include-only="src,lib" \
  --display-unlisted=true \
  --output="context.txt"
```

### View Help

```bash
tree_content --help
```

---

## How It Works

1. **Preamble**: Generates an LLM context header with metadata (generation time, project root, options used).
2. **Directory Tree**: Displays a text-based tree showing the full project structure.
3. **File Contents**: Lists each eligible file with its full content.

### Safety Features

- **Hidden files/dirs**: Skipped automatically (starting with `.`)
- **Modified during run**: Excluded to avoid partial reads
- **MIME type check**: Only plain-text files are included (text/*, application/json, application/xml, application/javascript)
- **Default exclusions**: Common build, vendor, cache, and sensitive files excluded automatically

---

## Default Exclusions

These files/directories are always excluded from content output but still listed as `[not listed]` with `--display-unlisted=true`.

### Directories

```
node_modules, vendor
.git, .svn
dist, build, target, coverage, .next, .nuxt, .out, .cache, tmp
.idea, .vscode
```

### Files

```
.DS_Store, Thumbs.db
composer.lock
package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb
```

### Patterns (matched in path)

```
.env, .env.*
.key, .pem, .crt
id_rsa, id_dsa
secrets, credentials
wp-config
```

### File Extensions

**Archives**: `.tar`, `.gz`, `.zip`, `.rar`, `.7z`, `.bz2`

**Databases**: `.sqlite`, `.db`, `.sql`

**Images**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`

**Videos**: `.mp4`, `.mov`, `.avi`, `.mkv`

**Audio**: `.mp3`, `.wav`, `.ogg`, `.flac`

**Documents**: `.pdf`, `.doc`, `.docx`

**Spreadsheets**: `.csv`, `.tsv`, `.xls`, `.xlsx`, `.ods`, `.numbers`

**Binaries**: `.exe`, `.dll`, `.so`, `.dylib`, `.bin`, `.iso`

---

## Why This Is Useful for LLMs

- **Complete project structure** with directory tree
- **Avoids leaking secrets** (.env, API keys, credentials)
- **Avoids dumping media/binary files** (images, videos, compiled code)
- **Avoids dependency folders** (node_modules, vendor)
- **Keeps prompt size reasonable** by filtering intelligently
- **MIME-type validation** ensures only readable text is included
- **Structured output** with clear file headers for easy parsing

### Typical Workflow

```bash
tree_content --output="context.txt"
```

Upload `context.txt` to your LLM and prompt it with full context.

---

## Requirements

- **Bash** 4.0+
- `find` command
- `file` command (for MIME type detection)
- `stat` command
- **Linux** or **macOS**

---

## License

MIT