#!/bin/bash

set -eu


unpack() {
    local image

    image=$1
    case "$image" in
        *.img)
            cat "$image"
            ;;
        *.gz)
            zcat "$image"
            ;;
        *.bz2)
            bzcat "$image"
            ;;
        *.xz)
            xzcat "$image"
            ;;
        *.zip)
            filename="${image##*/}"
            filename="${filename%.zip}.img"
            unzip -p "$image" "$filename"
            ;;
    esac
}


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


confirm() {
    local reply

    while true; do
        read -r -p "$@" reply
        if [ "$reply" = "y" ]; then
            return 0
        elif [ "$reply" = "n" ]; then
            return 1
        else
            echo "Invalid response" >&2
        fi
    done
}


info() {
    echo "[1;32m$*[0m" >&2
}


warning() {
    echo "[1;31m$*[0m" >&2
}


main() {
    local image dev

    if [ $# -eq 0 ]; then
        echo "Usage: ${0##*/} image-file-or-archive" >&2
        exit 2
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

    info "Current partition layout"
    sudo fdisk -l "$dev"
    echo >&2

    if [ -e "$(root_partition "$dev")" ]; then
        sudo mount "$(root_partition "$dev")" /mnt/root
        if [ -r /mnt/root/etc/os-release ]; then
            info "Content of /etc/os-release"
            cat /mnt/root/etc/os-release >&2
            echo >&2
        else
            warning "Cannot find /etc/os-release"
        fi
        sudo umount /mnt/root
    else
        warning "No root partition; blank media?"
    fi

    if confirm "Flash $image to $dev [y/n] "; then
        unpack "$image" | sudo dd of="$dev" bs=16M status=progress
        sudo sync
        if [ -e "$(boot_partition "$dev")" ]; then
            sudo mount "$(boot_partition "$dev")" /mnt/boot
            if [ -e /mnt/boot/user-data ]; then
                if confirm "Customize cloud-init configuration? [y/n] "; then
                    sudo sed -i \
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
                    echo doing it...
                fi
            fi
            if [ -e /mnt/boot/config.txt ]; then
                if ! grep "^disable_overscan=1" /mnt/boot/config.txt >/dev/null; then
                    sudo sed -i \
                        -e '/^#disable_overscan/ s/.*/disable_overscan=1/' \
                        /mnt/boot/config.txt
                fi
            fi
            sudo umount /mnt/boot
        else
            warning "No boot partition exists after flash!"
            exit 1
        fi
    fi
}


main "$@"
