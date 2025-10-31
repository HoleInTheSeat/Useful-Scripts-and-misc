#!/usr/bin/env bash
set -euo pipefail

prompt() {
    local msg="$1"
    local ans
    read -rp "$msg" ans
    echo "$ans"
}

hash_worker() {
    local idx="$1"
    local dir="$2"
    local hashfile="$dir/.hashlist.txt"
    local tmpfile="$dir/.hashlist.txt.tmp"
    local statusfile="/tmp/hash_status_${idx}.status"

    if [[ -f "$hashfile" ]]; then
        echo "Found existing hash file in $dir:"
        echo "   $hashfile"
        read -rp "Use existing file? (y to reuse, anything else to regenerate): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            echo "total=0" > "$statusfile"
            echo "done=1" >> "$statusfile"
            echo "processed=0" >> "$statusfile"
            echo "using_existing=1" >> "$statusfile"
            return 0
        fi
    fi

    : > "$tmpfile"
    echo "using_existing=0" > "$statusfile"
    echo "done=0" >> "$statusfile"
    echo "processed=0" >> "$statusfile"

    local total
    total=$(find "$dir" -type f -print0 | tr -cd '\0' | wc -c)
    echo "total=$total" >> "$statusfile"

    if (( total == 0 )); then
        mv -f "$tmpfile" "$hashfile"
        echo "done=1" > "$statusfile"
        echo "processed=0" >> "$statusfile"
        return 0
    fi

    local count=0
    find "$dir" -type f -print0 | while IFS= read -r -d '' file; do
        rel="${file#$dir/}"
        sha256sum "$file" | awk -v p="$rel" '{print $1 "\t" p}' >> "$tmpfile"
        count=$((count + 1))
        echo "processed=$count" > "$statusfile"
    done

    sort -o "$tmpfile" "$tmpfile"
    mv -f "$tmpfile" "$hashfile"
    echo "done=1" > "$statusfile"
    echo "processed=$count" >> "$statusfile"
}

monitor_progress() {
    local num="$1"
    shift
    local -a dirs=("$@")
    local all_done=0

    printf "\033[2J\033[H"
    while true; do
        all_done=1
        printf "\033[H"
        printf "Hashing progress:\n\n"

        for ((i=0; i<num; i++)); do
            local idx=$((i+1))
            local dir="${dirs[i]}"
            local statusfile="/tmp/hash_status_${idx}.status"
            local total="?"
            local processed="0"
            local done="0"
            local using_existing="0"

            if [[ -f "$statusfile" ]]; then
                while IFS='=' read -r k v; do
                    case "$k" in
                        total) total="$v" ;;
                        processed) processed="$v" ;;
                        done) done="$v" ;;
                        using_existing) using_existing="$v" ;;
                    esac
                done < "$statusfile"
            fi

            if [[ "$using_existing" == "1" ]]; then
                printf "[%d] %s : using existing .hashlist.txt\n" "$idx" "$dir"
            else
                printf "[%d] %s : %s / %s files\n" "$idx" "$dir" "$processed" "$total"
            fi

            if [[ "$done" != "1" ]]; then
                all_done=0
            fi
        done

        printf "\n"
        if [[ "$all_done" -eq 1 ]]; then
            break
        fi
        sleep 1
    done
    printf "All hashing workers finished.\n\n"
}

compare_hashlists() {
    local -n dirs_ref=$1
    local timestamp="$2"
    local out="./hash-comparison-summary-${timestamp}.txt"
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local combined="$tmpdir/combined.tsv"
    : > "$combined"

    local i=0
    for dir in "${dirs_ref[@]}"; do
        i=$((i+1))
        local hf="$dir/.hashlist.txt"
        if [[ ! -f "$hf" ]]; then
            echo "Warning: missing hash file for directory #$i: $dir" >> "$out"
            continue
        fi
        awk -v idx="$i" '{
            hash=$1
            $1=""
            sub(/^\t/,"")
            print $0 "\t" idx "\t" hash
        }' "$hf" >> "$combined"
    done

    sort -k1,1 "$combined" -o "$combined"

    {
      echo "Hash comparison summary for ${#dirs_ref[@]} directories"
      echo "Timestamp: $timestamp"
      echo
      echo "Directories:"
      local j=0
      for d in "${dirs_ref[@]}"; do
          j=$((j+1))
          echo "  [$j] $d"
      done
      echo
      echo "=== Files present in only a subset of directories ==="
    } > "$out"

    awk -F '\t' -v ndirs="${#dirs_ref[@]}" '
    {
        path = $1
        dir = $2
        if (path != prev_path && NR>1) {
            present_count=0
            for (i in have) present_count++
            if (present_count < ndirs) {
                printf "%s\tpresent in dirs: ", prev_path
                sep=""
                for (i=1;i<=ndirs;i++) if (i in have) { printf "%s%d", sep, i; sep="," }
                printf "\n"
            }
            delete have
        }
        prev_path=path
        have[dir]=1
    }
    END {
        present_count=0
        for (i in have) present_count++
        if (present_count < ndirs) {
            printf "%s\tpresent in dirs: ", prev_path
            sep=""
            for (i=1;i<=ndirs;i++) if (i in have) { printf "%s%d", sep, i; sep="," }
            printf "\n"
        }
    }' "$combined" >> "$out"

    {
      echo
      echo "=== Files with same relative path but DIFFERENT HASHES ==="
    } >> "$out"

    awk -F '\t' -v ndirs="${#dirs_ref[@]}" '
    {
        path = $1
        dir = $2
        hash = $3
        if (path != prev_path && NR>1) {
            uniq=0
            for (d in hash_per_dir) seen[ hash_per_dir[d] ]++
            for (h in seen) uniq++
            if (uniq>1) {
                printf "%s\n", prev_path
                for (i=1;i<=ndirs;i++) {
                    if (i in hash_per_dir) printf "  dir[%d]: %s\n", i, hash_per_dir[i]
                    else printf "  dir[%d]: <missing>\n", i
                }
                printf "\n"
            }
            delete hash_per_dir
            delete seen
        }
        prev_path=path
        hash_per_dir[dir]=hash
    }
    END {
        uniq=0
        for (d in hash_per_dir) seen[ hash_per_dir[d] ]++
        for (h in seen) uniq++
        if (uniq>1) {
            printf "%s\n", prev_path
            for (i=1;i<=ndirs;i++) {
                if (i in hash_per_dir) printf "  dir[%d]: %s\n", i, hash_per_dir[i]
                else printf "  dir[%d]: <missing>\n", i
            }
            printf "\n"
        }
    }' "$combined" >> "$out"

    echo "Summary written to: $out"
}

echo "Multi-directory hash comparer"
num_dirs=$(prompt "Enter number of directories to compare: ")
if ! [[ "$num_dirs" =~ ^[0-9]+$ ]] || (( num_dirs < 1 )); then
    echo "Invalid number of directories"
    exit 1
fi

declare -a DIRS
for ((i=1; i<=num_dirs; i++)); do
    dir=$(prompt "Enter full path for directory #$i: ")
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir"
        exit 1
    fi
    dir="${dir%/}"
    DIRS+=("$dir")
done

pids=()
for ((i=0; i<num_dirs; i++)); do
    idx=$((i+1))
    hash_worker "$idx" "${DIRS[i]}" &
    pids+=($!)
done

monitor_progress "$num_dirs" "${DIRS[@]}"

for pid in "${pids[@]}"; do
    wait "$pid" || true
done

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
compare_hashlists DIRS "$timestamp"

echo "Done."
