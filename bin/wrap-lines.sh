#!/usr/bin/env bash
set -euo pipefail

WIDTH=120

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") <file.md> [file2.md ...]" >&2
    echo "Wraps markdown prose lines to ~${WIDTH} characters without breaking words." >&2
    exit 1
fi

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "Warning: '$file' not found, skipping." >&2
        continue
    fi

    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT

    # fmt treats blank lines as paragraph breaks and wraps within paragraphs.
    # -s splits long lines but does not join short ones.
    # -w sets the target width.
    fmt -s -w "$WIDTH" "$file" > "$tmpfile"
    mv "$tmpfile" "$file"
    echo "Wrapped: $file"
done
