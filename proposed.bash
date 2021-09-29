#!/bin/bash

set -eu


main() {
    local release archive prop_prefs prop_repo

    if [ $EUID -ne 0 ]; then
        echo "Not running as root, re-execing under sudo" >&2
        exec sudo -- "$0" "$@"
    fi

    release="$(lsb_release -cs)"
    prop_prefs="/etc/apt/preferences.d/proposed-updates"
    prop_repo="/etc/apt/sources.list.d/ubuntu-$release-proposed.list"
    if [ "$(uname --machine)" = "x86_64" ]; then
        archive="http://archive.ubuntu.com/ubuntu"
    else
        archive="http://ports.ubuntu.com/ubuntu-ports"
    fi

    if [ -e "$prop_prefs" ]; then
        echo "Proposed updates appears to be enabled already" >&2
        exit 1
    fi

    cat << EOF > "$prop_prefs"
Package: *
Pin: release a=$release-proposed
Pin-Priority: 400
EOF
    cat << EOF > "$prop_repo"
deb $archive $release-proposed main restricted universe multiverse
# deb-src $archive $release-proposed main restricted universe multiverse
EOF

    apt update

    echo "Proposed updates enabled; install selected packages from the" >&2
    echo "-proposed pocket with sudo apt install -t $release-proposed PKG" >&2
}

main "$@"
