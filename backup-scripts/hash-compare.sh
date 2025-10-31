#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

prompt() {
    read -rp "$1" response
    echo "$response"
}

# Directory hashing with progress counter (fixed with mapfile)
hash_dir() {
    local dir="$1"
    local hashfile="$dir/.hashlist.txt"
    local counter_file="$dir/.hash_counter.tmp"

    if [[ -f "$hashfile" ]]; then
        echo "Found existing hash file in $dir:"
        echo "   $hashfile"
        read -rp "Use existing file? (y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            touch "$counter_file"
            return
        fi
    fi

    echo "Scanning $dir for files..."
    mapfile -d '' files < <(find "$dir" -type f -not -path "*/.zfs/*" -print0)
    local total_files=${#files[@]}
    echo "Found $total_files files to hash."
    : > "$hashfile"
    echo 0 > "$counter_file"

    for file in "${files[@]}"; do
        sha256sum "$file" | sed "s#^#${file} #" >> "$hashfile"
        count=$(($(cat "$counter_file") + 1))
        echo "$count" > "$counter_file"
    done

    sort -o "$hashfile" "$hashfile"
}

# Prompt for directories
echo "===== Multi-directory Hash Comparison ====="
num_dirs=$(prompt "Enter number of directories to compare: ")

declare -a dirs
for ((i=1; i<=num_dirs; i++)); do
    dir=$(prompt "Enter full path for directory #$i: ")
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir"
        exit 1
    fi
    dirs+=("$dir")
done

# Start parallel hashing
pids=()
for dir in "${dirs[@]}"; do
    hash_dir "$dir" &
    pids+=($!)
done

# Live progress monitor
echo "Hashing in progress..."
while :; do
    clear
    all_done=true
    for dir in "${dirs[@]}"; do
        counter_file="$dir/.hash_counter.tmp"
        total=$(find "$dir" -type f -not -path "*/.zfs/*" | wc -l)
        done_count=0
        [[ -f "$counter_file" ]] && done_count=$(cat "$counter_file")
        printf "%-40s : %5d / %d files\n" "$dir" "$done_count" "$total"
        if (( done_count < total )); then
            all_done=false
        fi
    done
    $all_done && break
    sleep 0.5
done

# Wait for all hashing jobs
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo "Hashing completed for all directories."

# Timestamped summary
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
summary_file="./hash-comparison-summary-${timestamp}.txt"
echo "=== Hash Comparison Summary (${timestamp}) ===" > "$summary_file"

# Read hashes into associative arrays
declare -A file_hashes
declare -A file_sizes
declare -A file_mtimes

for dir in "${dirs[@]}"; do
    while IFS= read -r line; do
        hash="${line%% *}"
        fullpath="${line#* }"
        # Normalize relative path
        relpath="$(realpath --relative-to="$dir" "$fullpath")"
        key="$dir|$relpath"
        file_hashes["$key"]="$hash"
        [[ -f "$fullpath" ]] && file_sizes["$key"]="$(stat -c%s "$fullpath")"
        [[ -f "$fullpath" ]] && file_mtimes["$key"]="$(stat -c%Y "$fullpath")"
    done < "$dir/.hashlist.txt"
done

# Collect all unique relative paths
declare -A all_paths
for key in "${!file_hashes[@]}"; do
    relpath="${key#*|}"
    all_paths["$relpath"]=1
done

# Compare files
for relpath in "${!all_paths[@]}"; do
    present_dirs=()
    hashes=()
    sizes=()
    mtimes=()
    for dir in "${dirs[@]}"; do
        key="$dir|$relpath"
        if [[ -n "${file_hashes[$key]:-}" ]]; then
            present_dirs+=("$dir")
            hashes+=("${file_hashes[$key]}")
            sizes+=("${file_sizes[$key]:-0}")
            mtimes+=("${file_mtimes[$key]:-0}")
        fi
    done

    if (( ${#present_dirs[@]} == 1 )); then
        echo "ONLY in ${present_dirs[0]}: ${present_dirs[0]}/$relpath" | tee -a "$summary_file"
    elif (( $(printf '%s\n' "${hashes[@]}" | sort -u | wc -l) > 1 )); then
        echo "DIFFERENT in multiple directories: $relpath" | tee -a "$summary_file"
        for idx in "${!present_dirs[@]}"; do
            dir="${present_dirs[$idx]}"
            size="${sizes[$idx]}"
            mtime="${mtimes[$idx]}"
            echo "  $dir/$relpath -> size: $size bytes, mtime: $(date -d @"$mtime" '+%Y-%m-%d %H:%M:%S')" | tee -a "$summary_file"
        done

        # Suggest likely correct: largest file, break ties with newest mtime
        max_idx=0
        max_size=${sizes[0]}
        max_mtime=${mtimes[0]}
        for i in "${!sizes[@]}"; do
            if (( sizes[i] > max_size )); then
                max_size=${sizes[i]}
                max_mtime=${mtimes[i]}
                max_idx=$i
            elif (( sizes[i] == max_size )) && (( mtimes[i] > max_mtime )); then
                max_mtime=${mtimes[i]}
                max_idx=$i
            fi
        done
        echo "  Suggested likely correct: ${present_dirs[$max_idx]}/$relpath" | tee -a "$summary_file"
    fi
done

# Clean up counters
for dir in "${dirs[@]}"; do
    rm -f "$dir/.hash_counter.tmp"
done

echo
echo "All comparisons complete."
echo "Summary saved to: $summary_file"
