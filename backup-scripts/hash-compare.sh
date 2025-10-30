#!/usr/bin/env bash
# ===============================================================
# Multi-directory hash compare utility
# Author: Deven & ChatGPT
# ===============================================================

set -euo pipefail

# ---------- Helper functions ----------
prompt() {
    read -rp "$1" response
    echo "$response"
}

hash_dir() {
    local dir="$1"
    local hashfile="$dir/.hashlist.txt"

    if [[ -f "$hashfile" ]]; then
        echo "⚠️  Found existing hash file in $dir:"
        echo "   $hashfile"
        read -rp "Use existing file? (y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            echo "Using existing hash list for $dir"
            return
        fi
    fi

    echo "🔍 Generating hash list for $dir..."
    find "$dir" -type f -exec sha256sum {} + | sed "s#${dir}/##" | sort > "$hashfile"
    echo "✅ Saved hash list to: $hashfile"
}

# ---------- Main script ----------
echo "===== Multi-directory Hash Comparison ====="
num_dirs=$(prompt "Enter number of directories to compare: ")

declare -a dirs
for ((i=1; i<=num_dirs; i++)); do
    dir=$(prompt "Enter full path for directory #$i: ")
    if [[ ! -d "$dir" ]]; then
        echo "❌ Directory not found: $dir"
        exit 1
    fi
    dirs+=("$dir")
done

# Generate or reuse hash lists
for dir in "${dirs[@]}"; do
    hash_dir "$dir"
done

# Prepare output summary
summary_file="./hash-comparison-summary.txt"
echo "=== Hash Comparison Summary ===" > "$summary_file"
echo "Comparing ${#dirs[@]} directories..." >> "$summary_file"

# Compare each pair of directories
for ((i=0; i<${#dirs[@]}-1; i++)); do
    for ((j=i+1; j<${#dirs[@]}; j++)); do
        dir1="${dirs[i]}"
        dir2="${dirs[j]}"
        file1="$dir1/.hashlist.txt"
        file2="$dir2/.hashlist.txt"

        echo -e "\n----------------------------------------" | tee -a "$summary_file"
        echo "Comparing:" | tee -a "$summary_file"
        echo "  1) $dir1" | tee -a "$summary_file"
        echo "  2) $dir2" | tee -a "$summary_file"
        echo "----------------------------------------" | tee -a "$summary_file"

        # Find files only in one or the other
        only1=$(comm -23 <(cut -d' ' -f2- "$file1") <(cut -d' ' -f2- "$file2"))
        only2=$(comm -13 <(cut -d' ' -f2- "$file1") <(cut -d' ' -f2- "$file2"))

        # Find changed files (same relative path but different hash)
        changed=$(join -j 2 <(sort -k2 "$file1") <(sort -k2 "$file2") | awk '$1=="" || $2!=$3 {print $2}')

        echo "=== Files only in $dir1 ===" | tee -a "$summary_file"
        echo "$only1" | tee -a "$summary_file"
        echo -e "\n=== Files only in $dir2 ===" | tee -a "$summary_file"
        echo "$only2" | tee -a "$summary_file"
        echo -e "\n=== Files with DIFFERENT HASHES ===" | tee -a "$summary_file"
        echo "$changed" | tee -a "$summary_file"

        echo -e "\nSummary Counts:" | tee -a "$summary_file"
        echo "Only in $dir1: $(echo "$only1" | grep -c . || true)" | tee -a "$summary_file"
        echo "Only in $dir2: $(echo "$only2" | grep -c . || true)" | tee -a "$summary_file"
        echo "Different Hashes: $(echo "$changed" | grep -c . || true)" | tee -a "$summary_file"
    done
done

echo
echo "✅ All comparisons complete!"
echo "📄 Summary saved to: $summary_file"
