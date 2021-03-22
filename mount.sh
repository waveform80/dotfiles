#!/bin/bash

set -eu


boot_partition() {
    local dev

    dev=$1
    case "$dev" in
        /dev/sd*)
            echo "$dev"1
            ;;
        /dev/mmcblk*)
            echo "$dev"p1
            ;;
        *)
            echo "Cannot determine boot partition for $dev" >&2
            return 1
            ;;
    esac
}


root_partition() {
    local dev

    dev=$1
    case "$dev" in
        /dev/sd*)
            echo "$dev"2
            ;;
        /dev/mmcblk*)
            echo "$dev"p2
            ;;
        *)
            echo "Cannot determine root partition for $dev" >&2
            return 1
            ;;
    esac
}


wait_for_sd() {
    local dev

    dev=$(inotifywait -q \
        --event create \
        --exclude "[^0-9]$" \
        --format "%w%f" \
        /dev)
    case "$dev" in
        /dev/sd*[0-9])
            dev=${dev%[0-9]}
            ;;
        /dev/mmcblk*p[0-9])
            dev=${dev%p[0-9]}
            ;;
    esac
    echo "$dev"
}


launch_shell() {
    local -a fields

    IFS=':' read -r -a fields < <(getent passwd "$USER")
    info "Launching shell; exit to unmount media"
    "${fields[6]}" -i || true
    info "Unmounting media"
}


info() {
    echo "[1;32m$*[0m" >&2
}


warning() {
    echo "[1;31m$*[0m" >&2
}


main() {
    local dev

    info "Waiting for SD card... "
    dev=$(wait_for_sd)
    echo "Found $dev" >&2
    echo >&2

    info "Current partition layout"
    sudo fdisk -l "$dev"
    echo >&2

    if [ -e "$(boot_partition "$dev")" ]; then
        info "Mounting boot partition on /mnt/boot"
        sudo mount "$(boot_partition "$dev")" /mnt/boot
        if [ -e "$(root_partition "$dev")" ]; then
            info "Mounting root partition on /mnt/root"
            sudo mount "$(root_partition "$dev")" /mnt/root
            launch_shell
            sudo umount /mnt/root
        else
            warning "No root partition; blank media?"
            launch_shell
        fi
        sudo umount /mnt/boot
    else
        warning "No boot partition; wtf?"
    fi
}


main "$@"
