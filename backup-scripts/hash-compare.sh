#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Prompt for directories
read -rp "Enter path for first directory: " DIR1
read -rp "Enter path for second directory: " DIR2

if [[ ! -d "$DIR1" ]]; then
    echo "Directory not found: $DIR1"
    exit 1
fi

if [[ ! -d "$DIR2" ]]; then
    echo "Directory not found: $DIR2"
    exit 1
fi

# Hash files in a directory, save to .hashlist.txt
hash_dir() {
    local dir="$1"
    local hashfile="$dir/.hashlist.txt"

    if [[ -f "$hashfile" ]]; then
        read -rp "Found existing hash file in $dir. Use it? (y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            echo "$hashfile"
            return
        fi
    fi

    echo "Hashing $dir..."
    : > "$hashfile"
    find "$dir" -type f -not -path "*/.zfs/*" -print0 | while IFS= read -r -d '' f; do
        sha256sum "$f" | sed "s#^#${f} #"
    done >> "$hashfile"

    echo "$hashfile"
}

HASH1=$(hash_dir "$DIR1")
HASH2=$(hash_dir "$DIR2")

# Prepare summary file
SUMMARY="hash-comparison-summary-$(date +"%Y-%m-%d_%H-%M-%S").txt"
echo "Hash Comparison Summary" > "$SUMMARY"
echo "Dir1: $DIR1 (hash file: $HASH1)" >> "$SUMMARY"
echo "Dir2: $DIR2 (hash file: $HASH2)" >> "$SUMMARY"
echo "" >> "$SUMMARY"

# Read hashes into associative arrays
declare -A hash1
declare -A hash2

while IFS= read -r line; do
    h="${line%% *}"
    f="${line#* }"
    rel="${f#$DIR1/}"
    hash1["$rel"]="$h"
done < "$HASH1"

while IFS= read -r line; do
    h="${line%% *}"
    f="${line#* }"
    rel="${f#$DIR2/}"
    hash2["$rel"]="$h"
done < "$HASH2"

# Compare files
all_files=()
for f in "${!hash1[@]}"; do
    all_files+=("$f")
done
for f in "${!hash2[@]}"; do
    all_files+=("$f")
done

# Remove duplicates
all_files=($(printf "%s\n" "${all_files[@]}" | sort -u))

for f in "${all_files[@]}"; do
    in1="${hash1[$f]:-}"
    in2="${hash2[$f]:-}"

    if [[ -z "$in1" ]]; then
        echo "ONLY in $DIR2: $DIR2/$f" >> "$SUMMARY"
    elif [[ -z "$in2" ]]; then
        echo "ONLY in $DIR1: $DIR1/$f" >> "$SUMMARY"
    elif [[ "$in1" != "$in2" ]]; then
        echo "DIFFERENT: $f" >> "$SUMMARY"
        echo "  $DIR1/$f -> hash: $in1" >> "$SUMMARY"
        echo "  $DIR2/$f -> hash: $in2" >> "$SUMMARY"
    fi
done

echo "Comparison complete. Summary saved to: $SUMMARY"
