hash_dir() {
    local dir="$1"
    local hashfile="$dir/.hashlist.txt"

    if [[ -f "$hashfile" ]]; then
        echo "Found existing hash file in $dir:"
        echo "   $hashfile"
        read -rp "Use existing file? (y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    : > "$hashfile"

    # Hash root directory first
    files=( "$dir"/* )
    files=( "${files[@]}" ) # ensure array expansion
    if (( ${#files[@]} > 0 )); then
        echo "Hashing ${#files[@]} files in $dir..."
        for f in "${files[@]}"; do
            [[ -f "$f" ]] || continue
            sha256sum "$f" | sed "s#^#${f} #" >> "$hashfile"
        done
    fi

    # Hash first-level subdirectories
    for sub in "$dir"/*/; do
        [[ -d "$sub" ]] || continue
        sub="${sub%/}" # remove trailing slash
        echo "Hashing ${sub}..."
        mapfile -d '' subfiles < <(find "$sub" -maxdepth 1 -type f -not -path "*/.zfs/*" -print0)
        for f in "${subfiles[@]}"; do
            sha256sum "$f" | sed "s#^#${f} #" >> "$hashfile"
        done
    done

    sort -o "$hashfile" "$hashfile"
}
