#!/bin/bash

set -eu

# shellcheck source=functions.bash
. "$(dirname "$(realpath "$0")")"/functions.bash

IMAGE=""
DEVICE=""


launch_shell() {
    local -a fields

    IFS=':' read -r -a fields < <(getent passwd "$USER")
    info "Launching shell; exit to unmount media"
    "${fields[6]}" -i || true
    info "Unmounting media"
}


clean_all_mounts() {
    while grep "^$DEVICE" /proc/mounts; do
        info "Removing mount at $(grep "^$DEVICE" | cut -f 2 -d " ")"
        umount "$DEVICE"
    done
}


cleanup() {
    [ -n "$DEVICE" ] && losetup -d "$DEVICE"
    rm -f "$IMAGE"
}


main() {
    local archive

    if [ $# -gt 1 ]; then
        echo "Usage: ${0##*/} [image-file-or-archive]" >&2
        exit 2
    fi

    if [ $EUID -ne 0 ]; then
        info "Not running as root, re-execing under sudo"
        exec sudo -- "$0" "$@"
    fi

    if [ $# -eq 0 ]; then
        info "Waiting for SD card... "
        DEVICE=$(wait_for_sd)
        echo "Found $DEVICE" >&2
    else
        archive="$1"
        if [ "${archive##*.}" = "img" ]; then
            IMAGE="$archive"
        else
            IMAGE=$(mktemp -t XXXXXXXX.img)
            trap cleanup EXIT
            info "Unpacking $archive"
            unpack "$archive" > "$IMAGE"
        fi
        DEVICE=$(losetup --read-only --partscan --find --show "$IMAGE")
        echo "Looped onto $DEVICE" >&2
    fi
    echo >&2

    info "Current partition layout"
    fdisk -l "$DEVICE"
    echo >&2

    boot_part="$(boot_partition "$DEVICE")"
    root_part="$(root_partition "$DEVICE")"

    if [ -e "$boot_part" ]; then
        info "Mounting $boot_part on /mnt/boot"
        mkdir -p /mnt/boot
        mount "$boot_part" /mnt/boot
        if [ -e "$root_part" ]; then
            info "Mounting $root_part on /mnt/root"
            mkdir -p /mnt/root
            mount "$root_part" /mnt/root
            launch_shell
            umount /mnt/root
        else
            warning "No root partition; blank media?"
            launch_shell
        fi
        umount /mnt/boot
    else
        warning "No boot partition; wtf?"
    fi

    clean_all_mounts "$boot_part"
    clean_all_mounts "$root_part"
}


main "$@"
