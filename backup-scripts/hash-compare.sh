#!/usr/bin/env bash
set -euo pipefail

# Prompt helper
prompt() {
    local msg="$1"
    local ans
    read -rp "$msg" ans
    echo "$ans"
}

# Hashing worker for a single directory (runs in background)
# Arguments: dir index (1-based), dir path
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
            # Mark as done immediately for monitoring
            echo "total=0" > "$statusfile"
            echo "done=1" >> "$statusfile"
            echo "processed=0" >> "$statusfile"
            echo "using_existing=1" >> "$statusfile"
            return 0
        fi
    fi

    # Prepare tmp file and status
    : > "$tmpfile"
    echo "using_existing=0" > "$statusfile"
    echo "done=0" >> "$statusfile"
    echo "processed=0" >> "$statusfile"

    # Count total files
    local total
    total=$(find "$dir" -type f -print | wc -l)
    echo "total=$total" >> "$statusfile"

    # If there are no files, finish quickly
    if (( total == 0 )); then
        mv -f "$tmpfile" "$hashfile"
        sed -n '1,0p' "$hashfile" >/dev/null 2>&1 || true
        echo "done=1" > "$statusfile"
        echo "processed=0" >> "$statusfile"
        return 0
    fi

    # iterate files and compute sha256sum, updating status periodically
    local count=0
    # Use while read to handle spaces in filenames
    find "$dir" -type f -print0 | while IFS= read -r -d '' file; do
        # compute hash and write "hash  relative/path" to tmpfile
        # remove leading dir/
        local rel
        rel="${file#$dir/}"
        sha256sum "$file" | awk -v p="$rel" '{print $1 "  " p}' >> "$tmpfile"

        count=$((count + 1))
        # update processed count in status file atomically
        # write processed only line appended then replace file
        echo "processed=$count" > "$statusfile"
        # avoid excessive disk churn: write processed every file but it's okay; if desired, throttle
    done

    # sort and move into final .hashlist.txt
    sort -o "$tmpfile" "$tmpfile"
    mv -f "$tmpfile" "$hashfile"

    echo "done=1" > "$statusfile"
    echo "processed=$count" >> "$statusfile"
    return 0
}

# Monitor function: prints live progress of all hash workers
# Arguments: number of directories, array of directory paths
monitor_progress() {
    local num="$1"
    shift
    local -a dirs=("$@")
    local all_done=0

    # Clear initial screen
    printf "\033[2J\033[H"
    while true; do
        all_done=1
        printf "\033[H"  # move cursor to top left
        printf "Hashing progress (press Ctrl-C to quit monitor, hashing continues in background):\n\n"

        for ((i=0; i<num; i++)); do
            local idx=$((i+1))
            local dir="${dirs[i]}"
            local statusfile="/tmp/hash_status_${idx}.status"
            local total="?"
            local processed="0"
            local done="0"
            local using_existing="0"

            if [[ -f "$statusfile" ]]; then
                # shellcheck disable=SC1090
                # read key=value pairs
                # Use a subshell to avoid polluting current vars
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
    # One final snapshot
    printf "All hashing workers finished.\n\n"
}

# Comparison across N directories using their .hashlist.txt files
# Produces: files present in only some dirs and files with same path but different hashes
compare_hashlists() {
    local -n dirs_ref=$1   # pass array name
    local timestamp="$2"
    local out="./hash-comparison-summary-${timestamp}.txt"
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    # Build a combined TSV: path<TAB>dir_index<TAB>hash
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
        # read lines "hash  path"
        # Use awk to output: path<TAB>dirindex<TAB>hash
        awk -v idx="$i" '{
            hash=$1
            # construct path from rest (handles spaces)
            $1=""
            sub(/^  /,"")
            path=$0
            print path "\t" idx "\t" hash
        }' "$hf" >> "$combined"
    done

    # sort and group by path
    sort -k1,1 "$combined" -o "$combined"

    # Now iterate groups by path
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

    # Use awk to analyze groups
    awk -F '\t' -v ndirs="${#dirs_ref[@]}" '
    function print_list(arr, n) {
        s=""
        for (i=1;i<=n;i++) {
            if (arr[i]!="") {
                if (s!="") s=s", ";
                s=s i
            }
        }
        return s
    }
    {
        path = $1
        dir = $2
        hash = $3
        if (path != prev_path && NR>1) {
            # process collected group prev_path
            # count dirs present
            present_count = 0
            for (i=1;i<=ndirs;i++) if (have[i]) present_count++
            if (present_count < ndirs) {
                printf "%s\tpresent in dirs: ", prev_path
                sep=""
                for (i=1;i<=ndirs;i++) if (have[i]) {
                    printf "%s%d", sep, i
                    sep=","
                }
                printf "\n" 
            }
            # reset arrays
            delete have
            delete hashes
        }
        prev_path = path
        have[dir]=1
        # record hash per dir (if multiple entries from same dir, keep first)
        if (!(dir in hashes)) hashes[dir]=hash
    }
    END {
        if (NR>0) {
            present_count = 0
            for (i=1;i<=ndirs;i++) if (have[i]) present_count++
            if (present_count < ndirs) {
                printf "%s\tpresent in dirs: ", prev_path
                sep=""
                for (i=1;i<=ndirs;i++) if (have[i]) {
                    printf "%s%d", sep, i
                    sep=","
                }
                printf "\n"
            }
        }
    }
    ' ndirs="${#dirs_ref[@]}" "$combined" >> "$out"

    # Now list files with same path but different hashes
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
            # analyze prev group
            # collect unique hashes
            uniq=0
            for (d in hash_per_dir) {
                seen[ hash_per_dir[d] ]++
            }
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
        prev_path = path
        hash_per_dir[dir]=hash
    }
    END {
        if (NR>0) {
            uniq=0
            for (d in hash_per_dir) {
                seen[ hash_per_dir[d] ]++
            }
            for (h in seen) uniq++
            if (uniq>1) {
                printf "%s\n", prev_path
                for (i=1;i<=ndirs;i++) {
                    if (i in hash_per_dir) printf "  dir[%d]: %s\n", i, hash_per_dir[i]
                    else printf "  dir[%d]: <missing>\n", i
                }
                printf "\n"
            }
        }
    }
    ' "$combined" >> "$out"

    # counts summary
    {
      echo
      echo "=== Summary counts ==="
      # count unique paths total
    } >> "$out"

    awk -F '\t' '
    { if ($1 != prev) { total_paths++; prev = $1 } }
    END { print "Total unique relative paths across all directories: " total_paths }' "$combined" >> "$out"

    # count how many paths are not present in all directories
    awk -F '\t' -v ndirs="${#dirs_ref[@]}" '
    {
        path=$1; dir=$2
        if (path!=prev && NR>1) {
            present=0
            for (i in had) present++
            if (present < ndirs) subset++
            if (present < ndirs) misscount++
            delete had
        }
        prev=path
        had[dir]=1
    }
    END {
        # last group
        present=0
        for (i in had) present++
        if (present < ndirs) subset++
        print "Paths present in only a subset of directories: " subset
    }' "$combined" >> "$out"

    # count different-hash paths
    awk -F '\t' '
    {
        path=$1; dir=$2; hash=$3
        if (path!=prev && NR>1) {
            # analyze prev path
            unique=0
            for (h in seen) unique++
            if (unique>1) diffcount++
            delete seen
        }
        seen[hash]=1
        prev=path
    }
    END {
        # last
        unique=0
        for (h in seen) unique++
        if (unique>1) diffcount++
        print "Paths with differing hashes across dirs: " diffcount
    }' "$combined" >> "$out"

    echo "Summary written to: $out"
}

# Main script flow
echo "Multi-directory hash comparer"
num_dirs=$(prompt "Enter number of directories to compare: ")
# validate numeric
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
    # trim trailing slash
    dir="${dir%/}"
    DIRS+=("$dir")
done

# Launch hash workers in background
pids=()
for ((i=0; i<num_dirs; i++)); do
    idx=$((i+1))
    hash_worker "$idx" "${DIRS[i]}" &
    pids+=($!)
done

# Start monitor (in foreground) until all done
monitor_progress "$num_dirs" "${DIRS[@]}"

# Wait for all background workers to ensure they completed
for pid in "${pids[@]}"; do
    wait "$pid" || true
done

# create timestamp and run comparison
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
compare_hashlists DIRS "$timestamp"

echo "Done."
