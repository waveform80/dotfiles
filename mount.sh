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

    while true; do
        dev=$(inotifywait -q \
            --event create \
            --exclude "[^0-9]$" \
            --format "%w%f" \
            /dev)
        case "$dev" in
            /dev/sd*[0-9])
                dev=${dev%[0-9]}
                break
                ;;
            /dev/mmcblk*p[0-9])
                dev=${dev%p[0-9]}
                break
                ;;
            /dev/mmcblk[0-9])
                break
                ;;
            *)
                echo "Ignoring $dev" >&2
                ;;
        esac
    done
    echo "$dev"
}


launch_shell() {
    local -a fields

    IFS=':' read -r -a fields < <(getent passwd "$USER")
    info "Launching shell; exit to unmount media"
    "${fields[6]}" -i || true
    info "Unmounting media"
}


clean_all_mounts() {
    local device

    device="$1"

    while grep "^$device" /proc/mounts; do
        info "Removing mount at $(grep "^$device" | cut -f 2 -d " ")"
        umount "$device"
    done
}


info() {
    echo "[1;32m$*[0m" >&2
}


warning() {
    echo "[1;31m$*[0m" >&2
}


main() {
    local dev

    if [ $EUID -ne 0 ]; then
        info "Not running as root, re-execing under sudo"
        exec sudo -- "$0" "$@"
    fi

    info "Waiting for SD card... "
    dev=$(wait_for_sd)
    echo "Found $dev" >&2
    echo >&2

    info "Current partition layout"
    fdisk -l "$dev"
    echo >&2

    boot_part="$(boot_partition "$dev")"
    root_part="$(root_partition "$dev")"

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
