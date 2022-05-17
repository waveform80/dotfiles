#!/bin/bash

set -eu

# shellcheck source=functions.bash
. "$(dirname "$(realpath "$0")")"/functions.bash


show_parts() {
    local dev

    info "Partition layout"
    dev="$1"
    fdisk -l "$dev" || true
    echo >&2
}


show_release() {
    local dev root_part

    dev="$1"
    root_part="$(root_partition "$dev")"
    if [ -e "$root_part" ]; then
        if mount "$root_part" /mnt/root; then
            if [ -r /mnt/root/etc/os-release ]; then
                info "Content of /etc/os-release"
                cat /mnt/root/etc/os-release >&2
                echo >&2
            else
                warning "Cannot find /etc/os-release"
            fi
            umount /mnt/root
        else
            warning "Cannot mount root partition; bad media?"
        fi
    else
        warning "No root partition; blank media?"
    fi
}


umount_parts() {
    local dev

    dev="$1"
    pattern="$(all_partitions "$dev")"

    info "Waiting for other mounts to show up"
    sleep 3
    while grep -q "$pattern" /proc/mounts; do
        for part in $(grep -o "$pattern" /proc/mounts); do
            info "Unmounting $part"
            umount $part
        done
        sleep 3
    done
}


fix_config() {
    local dev boot_part ap password

    dev="$1"
    boot_part="$(boot_partition "$dev")"
    if [ -e "$boot_part" ]; then
        mount "$boot_part" /mnt/boot
        if [ -e /mnt/boot/user-data ]; then
            if confirm "Customize cloud-init configuration? [y/n] "; then
                cat << EOF > /mnt/boot/user-data
#cloud-config

hostname: miss-piggy

chpasswd:
  expire: false
  list:
  - ubuntu:raspberry

keyboard:
  model: pc105
  layout: gb
  options: ctrl:nocaps

ssh_import_id:
- lp:waveform
EOF
            fi
        fi
        if [ -e /mnt/boot/network-config ]; then
            if confirm "Add wifi configuration? [y/n] "; then
                read -r -p "Access point name: " ap
                read -r -p "Access point password: " password
                sed -i -r \
                    -e '/^#wifis:/,+6 s/^#//' \
                    -e "s/myhomewifi:/${ap}:/" \
                    -e "s/\"S3kr1t\"/\"${password}\"/" /mnt/boot/network-config
            fi
            if confirm "Remove ethernet configuration? [y/n] "; then
                sed -i -r \
                    -e '/^ethernets:/,+3 s/^/#/' /mnt/boot/network-config
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
        umount_parts "$dev"
        unpack "$image" | dd of="$dev" bs=16M status=progress
        sync
        show_parts "$dev"
        show_release "$dev"
        fix_config "$dev"
    fi
}


main "$@"
