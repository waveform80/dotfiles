#!/bin/bash

set -eu

# shellcheck source=functions.bash
. "$(dirname "$(realpath "$0")")"/functions.bash


show_parts() {
    local dev

    info "Partition layout"
    dev="$1"
    fdisk -l "$dev"
    echo >&2
}


show_release() {
    local dev root_part

    dev="$1"
    root_part="$(root_partition "$dev")"
    if [ -e "$root_part" ]; then
        mount "$root_part" /mnt/root
        if [ -r /mnt/root/etc/os-release ]; then
            info "Content of /etc/os-release"
            cat /mnt/root/etc/os-release >&2
            echo >&2
        else
            warning "Cannot find /etc/os-release"
        fi
        umount /mnt/root
    else
        warning "No root partition; blank media?"
    fi
}


fix_config() {
    local dev boot_part

    dev="$1"
    boot_part="$(boot_partition "$dev")"
    if [ -e "$boot_part" ]; then
        mount "$boot_part" /mnt/boot
        if [ -e /mnt/boot/user-data ]; then
            if confirm "Customize cloud-init configuration? [y/n] "; then
                sed -i \
                    -e 's/expire: true/expire: false/' \
                    -e 's/ubuntu:ubuntu/ubuntu:raspberry/' \
                    -e 's/^ssh_pwauth: true/ssh_pwauth: false/' \
                    -e 's/^#ssh_import_id/ssh_import_id/' \
                    -e 's/^#- lp:my_launchpad_username/- lp:waveform/' \
                    /mnt/boot/user-data
            fi
        fi
        if [ -e /mnt/boot/network-config ]; then
            if confirm "Add wifi configuration? [y/n] "; then
                echo FIXME
            fi
        fi
        if [ -e /mnt/boot/config.txt ]; then
            if ! grep "^disable_overscan=1" /mnt/boot/config.txt >/dev/null; then
                sed -i \
                    -e '/^#disable_overscan/ s/.*/disable_overscan=1/' \
                    /mnt/boot/config.txt
            fi
        fi
        umount /mnt/boot
    else
        warning "No boot partition exists after flash!"
        exit 1
    fi
}


main() {
    local image dev

    if [ $# -ne 1 ]; then
        echo "Usage: ${0##*/} image-file-or-archive" >&2
        exit 2
    fi

    if [ $EUID -ne 0 ]; then
        info "Not running as root, re-execing under sudo"
        exec sudo -- "$0" "$@"
    fi

    image=$1

    if [ ! -r "$image" ]; then
        warning "Cannot read $image"
        return 1
    fi

    info "Waiting for SD card... "
    dev=$(wait_for_sd)
    echo "Found $dev" >&2
    echo >&2

    show_parts "$dev"
    show_release "$dev"

    if confirm "Flash $image to $dev [y/n] "; then
        unpack "$image" | dd of="$dev" bs=16M status=progress
        sync
        show_parts "$dev"
        show_release "$dev"
        fix_config "$dev"
    fi
}


main "$@"
