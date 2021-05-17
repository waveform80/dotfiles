#!/bin/sh

set -e
MY_PATH=$(dirname $(readlink -f $0))

main() {
    case "$1" in
        start)   start   ;;
        split)   split   ;;
        logical) logical ;;
        review)  review  ;;
        finish)  finish  ;;
        *)
            echo "Usage:" $(basename $0) "start/split/logical/review/finish"
            exit 1
            ;;
    esac
    exit 0
}

start() {
    work_dir_clean

    echo "Fetching origin"
    git fetch origin

    local merge_base=$(git merge-base origin/debian/sid origin/ubuntu/devel)
    local old_ubuntu=$(get_version origin/ubuntu/devel)
    local new_debian=$(get_version origin/debian/sid)
    local old_debian=$(get_version $merge_base)

    [ ${old_debian} = ${new_debian} ] && \
        die "Current version is based on Debian unstable!"

    git checkout origin/debian/sid 2>/dev/null
    echo "Removing old tags"
    git tag -d old/ubuntu old/debian new/debian 2>/dev/null || true
    echo "Refreshing stale branches"
    git branch -D debian/sid ubuntu/devel 2>/dev/null || true

    echo "Creating new tags:"
    git tag old/ubuntu origin/ubuntu/devel
    echo "  old/ubuntu pointing at import/${old_ubuntu}"
    git tag old/debian $merge_base
    echo "  old/debian pointing at import/${old_debian}"
    git tag new/debian origin/debian/sid
    echo "  new/debian pointing at import/${new_debian}"
    git tag reconstruct/${old_ubuntu} old/ubuntu
    git checkout old/ubuntu
    echo "Create split and tag with:"
    echo "  git rebase -i old/debian"
    echo "  merge split"
}

split() {
    work_dir_clean
    descends_from old/debian
    not_descends_from new/debian
    [ -z "$(git diff old/ubuntu)" ] || die "Split does not match old/ubuntu!"

    local old_debian=$(get_version old/debian)
    local new_debian=$(get_version new/debian)
    local old_ubuntu=$(get_version old/ubuntu)

    git tag split/${old_ubuntu}
    echo "Created split/${old_ubuntu} pointing at HEAD"
    echo "Clean up logical branch and tag with:"
    echo "  git rebase -i old/debian"
    echo "  merge logical"
}

logical() {
    work_dir_clean
    descends_from old/debian
    not_descends_from new/debian
    for file in $(git diff --name-only old/ubuntu); do
        case $file in
            debian/control) continue ;;
            debian/changelog) continue ;;
            *) die "Logical has unexpected changes in $file" ;;
        esac
    done
    git diff old/ubuntu -- debian/control | \
        grep "^[+-]" | \
        grep -v "^\(+++\|---\)" | \
        {
            while read line; do
                case $line in
                    [+-]Maintainer:*) continue ;;
                    -XSBC-Original-Maintainer:*) continue ;;
                    *) die "Logical has unexpected changes in d/control" ;;
                esac
            done
        }

    local old_debian=$(get_version old/debian)
    local new_debian=$(get_version new/debian)
    local old_ubuntu=$(get_version old/ubuntu)

    git tag logical/${old_ubuntu}
    echo "Created logical/${old_ubuntu} pointing at HEAD"
    echo "Rebase onto new/debian and finish with:"
    echo "  git rebase --onto new/debian old/debian logical/${old_ubuntu}"
    echo "  merge review"
}

review() {
    work_dir_clean
    descends_from new/debian

    local old_debian=$(get_version old/debian)
    local new_debian=$(get_version new/debian)
    local old_ubuntu=$(get_version old/ubuntu)
    local new_ubuntu=${new_debian}ubuntu1

    git tag logical/${new_ubuntu}
    echo "Created logical/${new_ubuntu} pointing at HEAD"
    echo "Review changes and generate changelogs with:"
    echo "  git range-diff old/debian..logical/${old_ubuntu} new/debian..logical/${new_ubuntu}"
    echo "  merge finish"
}

finish() {
    work_dir_clean
    descends_from new/debian

    local old_debian=$(get_version old/debian)
    local new_debian=$(get_version new/debian)
    local old_ubuntu=$(get_version old/ubuntu)
    local new_ubuntu=${new_debian}ubuntu1

    tmpdir=$(mktemp -d /tmp/merge.XXXX)
    trap 'rm -fr -- "${tmpdir}"' EXIT

    echo "Merging changelogs"
    git cat-file blob old/debian:debian/changelog > ${tmpdir}/changelog.old.debian
    git cat-file blob old/ubuntu:debian/changelog > ${tmpdir}/changelog.old.ubuntu
    git cat-file blob new/debian:debian/changelog > ${tmpdir}/changelog.new.debian
    dpkg-mergechangelogs \
        ${tmpdir}/changelog.old.debian \
        ${tmpdir}/changelog.old.ubuntu \
        ${tmpdir}/changelog.new.debian > debian/changelog
    git commit debian/changelog -m merge-changelog
    debchange -i "Merge from Debian unstable. Remaining changes:" --distribution $(distro-info --devel)
    debchange -a "Removed obsolete patches/changes:"
    debchange -a "Removed patches obsoleted/merged by upstream:"
    git log new/debian.. --topo-order --reverse --format="%B%n### END ###" | \
        $MY_PATH/mergedch.py > ${tmpdir}/changelog.insert
    sed -i -e "3r ${tmpdir}/changelog.insert" debian/changelog
    debchange -r
    git commit debian/changelog -m reconstruct-changelog
    echo "Updating maintainer"
    update-maintainer && git commit -m update-maintainer -- debian/control || true
    git tag merge/${new_ubuntu}
    echo "Created merge/${new_ubuntu} pointing at HEAD"
    echo "Now build source and test with:"
    echo "  sbuild --no-arch-any --no-arch-all --source --force-orig-source"
    echo "  autopkgtest -- schroot $(ubuntu-distro-info --devel)-$(dpkg-architecture -q DEB_HOST_ARCH)"
}

die() {
    echo "$@" >&2
    exit 1
}

work_dir_clean() {
    [ -z "$(git status --porcelain)" ] || die "Working directory not clean!"
}

descends_from() {
    local commitish=$1

    git merge-base --is-ancestor ${commitish} HEAD || \
        die "HEAD does not descend from ${commitish}!"
}

not_descends_from() {
    local commitish=$1

    git merge-base --is-ancestor ${commitish} HEAD && \
        die "HEAD descends from ${commitish}!" || true
}

get_version() {
    local commitish=$1

    git cat-file blob ${commitish}:debian/changelog | \
        head -n 1 | \
        sed -n -e 's/.*(//' -e 's/).*//p'
}

main "$@"
