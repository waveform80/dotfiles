unpack() {
    local image

    image="$1"
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
        *.zst|*.zstd)
            zstdcat "$image"
            ;;
        *.zip)
            filename="${image##*/}"
            filename="${filename%.zip}.img"
            unzip -p "$image" "$filename"
            ;;
        *)
            echo "Cannot determine image/compression format" >&2
            return 1
            ;;
    esac
}


boot_partition() {
    local dev

    dev="$1"
    case "$dev" in
        /dev/sd*)
            echo "$dev"1
            ;;
        /dev/mmcblk*|/dev/loop*)
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

    dev="$1"
    case "$dev" in
        /dev/sd*)
            echo "$dev"2
            ;;
        /dev/mmcblk*|/dev/loop*)
            echo "$dev"p2
            ;;
        *)
            echo "Cannot determine root partition for $dev" >&2
            return 1
            ;;
    esac
}


all_partitions() {
    local dev

    dev="$1"
    case "$dev" in
        /dev/sd*)
            echo "${dev}[0-9][0-9]*"
            ;;
        /dev/mmcblk*|/dev/loop*)
            echo "${dev}p[0-9][0-9]*"
            ;;
        *)
            echo "Cannot generate partitions pattern for $dev" >&2
            return 1
            ;;
    esac
}


wait_for_sd() {
    local dev real_dev

    dev=$(inotifywait -q \
        --event create \
        --exclude "[^0-9]$" \
        --format "%w%f" \
        /dev)
    case "$dev" in
        /dev/sg[0-9])
            for ((delay=0; delay<5; delay++)); do
                sleep "$delay"
                real_dev=$(lsscsi --brief --generic | \
                    awk -v dev="$dev" '$3 == dev { print $2; }')
                if [ "${real_dev#/dev/}" != "$real_dev" ]; then
                    dev=$real_dev
                    break
                fi
                echo "Waiting for SCSI to settle" >&2
            done
            if [ "${real_dev#/dev/}" == "$real_dev" ]; then
                echo "Failed to resolve SCSI device" >&2
                return 1
            fi
            ;;
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
