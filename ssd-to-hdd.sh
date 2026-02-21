#!/bin/bash
set -euo pipefail

SSD_RECORDINGS="/media/frigate/recordings"
HDD_RECORDINGS="/media/frigate-hdd/recordings"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') — $*"
}

sync_to_hdd() {
    log "Starting SSD → HDD sync"

    find "$SSD_RECORDINGS" -type f -print0 | while IFS= read -r -d '' ssd_file; do
        rel_path="${ssd_file#$SSD_RECORDINGS/}"
        hdd_file="$HDD_RECORDINGS/$rel_path"

        [ -f "$hdd_file" ] && continue

        mkdir -p "$(dirname "$hdd_file")"
        mv "$ssd_file" "$hdd_file"
        ln -s "$hdd_file" "$ssd_file"
        log "Moved: $rel_path"
    done

    log "SSD → HDD sync complete"
}

cleanup_hdd() {
    log "Starting HDD cleanup"

    find "$HDD_RECORDINGS" -type f -print0 | while IFS= read -r -d '' hdd_file; do
        rel_path="${hdd_file#$HDD_RECORDINGS/}"
        ssd_path="$SSD_RECORDINGS/$rel_path"

        # If Frigate removed the entry from SSD entirely, delete from HDD
        if [ ! -e "$ssd_path" ] && [ ! -L "$ssd_path" ]; then
            rm "$hdd_file"
            log "Cleaned: $rel_path"
        fi
    done

    find "$HDD_RECORDINGS" -mindepth 1 -type d -empty -delete 2>/dev/null || true

    log "HDD cleanup complete"
}

repair_symlinks() {
    log "Starting symlink repair"

    find "$HDD_RECORDINGS" -type f -print0 | while IFS= read -r -d '' hdd_file; do
        rel_path="${hdd_file#$HDD_RECORDINGS/}"
        ssd_path="$SSD_RECORDINGS/$rel_path"

        # Skip if a valid symlink already exists
        [ -L "$ssd_path" ] && [ -e "$ssd_path" ] && continue

        # Remove broken symlink if present
        [ -L "$ssd_path" ] && rm "$ssd_path"

        mkdir -p "$(dirname "$ssd_path")"
        ln -s "$hdd_file" "$ssd_path"
        log "Repaired: $rel_path"
    done

    log "Symlink repair complete"
}

revert() {
    log "Starting revert"

    find "$SSD_RECORDINGS" -type l -print0 | while IFS= read -r -d '' ssd_link; do
        rel_path="${ssd_link#$SSD_RECORDINGS/}"
        hdd_file="$HDD_RECORDINGS/$rel_path"

        if [ -f "$hdd_file" ]; then
            rm "$ssd_link"
            mv "$hdd_file" "$ssd_link"
            log "Reverted: $rel_path"
        else
            rm "$ssd_link"
            log "Removed broken symlink: $rel_path"
        fi
    done

    find "$HDD_RECORDINGS" -mindepth 1 -type d -empty -delete 2>/dev/null || true

    log "Revert complete"
}

case "${1:-}" in
    sync)
        sync_to_hdd
        cleanup_hdd
        ;;
    repair)
        repair_symlinks
        ;;
    revert)
        revert
        ;;
    ""|*)
        echo "Usage: $0 {sync|repair|revert}"
        exit 1
        ;;
esac
