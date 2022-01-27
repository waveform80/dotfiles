#!/bin/bash

set -e
MY_PATH=$(dirname "$(readlink -f "$0")")
MSG="[0;33m"
TEMPLATE="[0;32m"
LINK="[1;36m"
RESET="[0m"


main() {
    case "$1" in
        clone)
            shift
            clone "$@"
            ;;
        start)
            start_
            ;;
        split)
            split
            ;;
        logical)
            shift
            logical "$@"
            ;;
        review)
            review
            ;;
        finish)
            shift
            finish "$@"
            ;;
        test)
            test_
            ;;
        build)
            build
            ;;
        whatnow)
            shift
            whatnow "$@"
            ;;
        *)
            echo "Usage:" "$(basename "$0")" "clone/start/split/logical/review/finish"
            exit 1
            ;;
    esac
    exit 0
}


whatnow() {
    echo -n $MSG
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        local project

        project="$1"

        if [ -z "$project" ]; then
            cat << EOF
Clone a project with:
$RESET
\$ merge clone \$project
EOF
        else
            cat << EOF
Start the merge with:
$RESET
\$ cd $project
\$ merge start
EOF
        fi
    elif ! tag_exists new/debian; then
        cat << EOF
Start the merge with:
$RESET
\$ merge start
EOF
    else
        local top_level parent
        local old_debian new_debian debian_sid
        local old_ubuntu ubuntu_devel old_ubuntu_tag
        local new_ubuntu new_ubuntu_tag
        local autopkgtest_log source_changes debdiff
        local merge_bug lpuser

        lpuser=$(git config --get ubuntu.lpuser)
        top_level=$(git rev-parse --show-toplevel)
        parent=$(dirname "${top_level}")
        project=$(get_project new/debian)
        old_debian=$(get_version old/debian)
        new_debian=$(get_version new/debian)
        debian_sid=$(get_version origin/debian/sid)
        old_ubuntu=$(get_version old/ubuntu)
        ubuntu_devel=$(get_version origin/ubuntu/devel)
        old_ubuntu_tag=$(version_to_tag "$old_ubuntu")
        new_ubuntu=${new_debian}ubuntu1
        new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
        autopkgtest_log="${parent}/${project}_${new_ubuntu}.autopkgtest"
        source_changes="${parent}/${project}_${new_ubuntu}_source.changes"
        merge_bug=$(get_merge_bug merge/"$new_ubuntu_tag")
        [ -z "$merge_bug" ] && merge_bug="$1"
        [ -z "$merge_bug" ] && merge_bug="MERGE_BUG"
        debdiff="${parent}/1-${merge_bug}.debdiff"

        if [ "$new_debian" != "$debian_sid" ] || [ "$old_ubuntu" != "$ubuntu_devel" ]; then
            cat << EOF
Start the merge with:
$RESET
\$ merge start
EOF
        elif ! tag_exists reconstruct/"$old_ubuntu_tag"; then
            cat << EOF
Start the merge with:
$RESET
\$ merge start
EOF
        elif ! tag_exists split/"$old_ubuntu_tag"; then
            cat << EOF
Split version commits into individual changes with no changelog or maintainer
changes with:
$RESET
\$ git rebase -i old/debian # and <edit> each version commit
$MSG
For each edited commit, reset the working tree with:
$RESET
\$ git reset HEAD^
$MSG
For each change mentioned in the changelog, make a commit representing that
change, copying the changelog entry(/entries) into the commit message with:
$RESET
\$ git add --patch ...
\$ git commit
$MSG
Commit changelog and maintainer info separately at the end with:
$RESET
\$ git commit debian/changelog -m changelog
\$ git commit debian/control -m metadata
\$ git rebase --continue
$MSG
Finally, continue the merge with:
$RESET
\$ merge split
$MSG
At any time you can show this message again with:
$RESET
\$ merge whatnow
EOF
        elif ! tag_exists logical/"$old_ubuntu_tag"; then
            cat << EOF
Construct a "clean" set of changes by removing redundant or upstreamed changes
with:
$RESET
\$ git rebase -i old/debian # and remove redundant commits
\$ merge logical
EOF
        elif ! tag_exists logical/"$new_ubuntu_tag"; then
            cat << EOF
Rebase the "clean" set of changes onto new/debian and review with:
$RESET
\$ git rebase --onto new/debian old/debian logical/$old_ubuntu_tag
\$ merge review
EOF
        elif ! tag_exists merge/"$new_ubuntu_tag"; then
            cat << EOF
Review the changes, open a merge bug on Launchpad, then reconstruct changelogs
and finish the merge with:
$RESET
\$ git range-diff old/debian..logical/$old_ubuntu_tag new/debian..logical/$new_ubuntu_tag
\$ www-browser ${LINK}http://pad.lv/fb/u/$project${RESET}
\$ merge finish \$merge_bug
$MSG
Bug template:
$TEMPLATE
Please merge $project $new_debian from Debian unstable.

Updated changelog and diff against Debian unstable to be attached below.
EOF
        elif ! [ -e "$autopkgtest_log" ]; then
            if [ -e debian/tests/control ]; then
                cat << EOF
Run autopkgtest on your merged package:
$RESET
\$ merge test
EOF
            else
                echo "No tests available" > "${autopkgtest_log}"
            fi
        elif ! [ -e "$debdiff" -a -e "$source_changes" ]; then
            cat << EOF
Push all tags, build a source package and generate a debdiff for it:
$RESET
\$ merge build
EOF
        else
cat << EOF
Attach ${debdiff}
to ${LINK}LP: #$merge_bug${MSG} with something like the following message:
$TEMPLATE
Attaching patch against Debian unstable. For ease of review, relevant commits
and tags have been pushed to the following repository:

  https://code.launchpad.net/~$lpuser/ubuntu/+source/$project/+git/$project

Specifically:

* logical/$old_ubuntu_tag represents our split-out delta on top of old/debian ($old_debian)
* logical/$new_ubuntu_tag represents our rebased delta on top of new/debian ($new_debian)
* merge/$new_ubuntu_tag just adds changelog and maintainer changes on top of logical/$new_ubuntu_tag

Hence, the following command may produce output useful to the purposes of review:

  git range-diff old/debian..logical/$old_ubuntu_tag new/debian..logical/$new_ubuntu_tag
EOF
        fi
    fi
    echo -n $RESET
}


clone() {
    local project lpuser lpprefix

    project="$1"
    lpuser=$(git config --get ubuntu.lpuser)
    lpprefix="git+ssh://$lpuser@git.launchpad.net"

    git clone "$lpprefix"/ubuntu/+source/"$project" "$project"
    pushd "$project"
    git remote add "$lpuser" "$lpprefix"/~"$lpuser"/ubuntu/+source/"$project"
    popd

    whatnow "$project"
}


start_() {
    local merge_base old_ubuntu old_ubuntu_tag new_debian old_debian

    work_dir_clean

    echo "Fetching origin"
    git fetch origin

    merge_base=$(git merge-base origin/debian/sid origin/ubuntu/devel)
    old_ubuntu=$(get_version origin/ubuntu/devel)
    old_ubuntu_tag=$(version_to_tag "$old_ubuntu")
    new_debian=$(get_version origin/debian/sid)
    old_debian=$(get_version "$merge_base")

    [ "${old_debian}" = "${new_debian}" ] && \
        die "Current version is based on Debian unstable!"

    git checkout origin/debian/sid 2>/dev/null
    echo "Removing old tags"
    git tag -d old/ubuntu old/debian new/debian 2>/dev/null || true
    echo "Refreshing stale branches"
    git branch -D debian/sid ubuntu/devel 2>/dev/null || true

    echo "Creating new tags:"
    git tag old/ubuntu origin/ubuntu/devel
    echo "  old/ubuntu pointing at import/${old_ubuntu}"
    git tag old/debian "$merge_base"
    echo "  old/debian pointing at import/${old_debian}"
    git tag new/debian origin/debian/sid
    echo "  new/debian pointing at import/${new_debian}"
    git tag reconstruct/"$old_ubuntu_tag" old/ubuntu
    git checkout old/ubuntu

    whatnow
}


split() {
    local old_debian new_debian old_ubuntu old_ubuntu_tag

    work_dir_clean
    descends_from old/debian
    not_descends_from new/debian
    [ -z "$(git diff old/ubuntu)" ] || die "Split does not match old/ubuntu!"

    old_debian=$(get_version old/debian)
    new_debian=$(get_version new/debian)
    old_ubuntu=$(get_version old/ubuntu)
    old_ubuntu_tag=$(version_to_tag "$old_ubuntu")

    git tag split/"$old_ubuntu_tag"
    echo "Created split/$old_ubuntu_tag pointing at HEAD"

    whatnow
}


logical() {
    local old_ubuntu old_ubuntu_tag force

    force=0
    case "$1" in
        --force|-f)
            force=1
            ;;
    esac

    work_dir_clean
    descends_from old/debian
    not_descends_from new/debian
    if [ $force -eq 0 ]; then
        for file in $(git diff --name-only old/ubuntu); do
            case "$file" in
                debian/control) continue ;;
                debian/changelog) continue ;;
                *) die "Logical has unexpected changes in $file" ;;
            esac
        done
        git diff old/ubuntu -- debian/control | \
            grep "^[+-]" | \
            grep -v "^\(+++\|---\)" | \
            {
                while read -r line; do
                    case $line in
                        [+-]Maintainer:*) continue ;;
                        -XSBC-Original-Maintainer:*) continue ;;
                        *) die "Logical has unexpected changes in d/control" ;;
                    esac
                done
            }
    fi

    old_ubuntu=$(get_version old/ubuntu)
    old_ubuntu_tag=$(version_to_tag "$old_ubuntu")

    git tag logical/"$old_ubuntu_tag"
    echo "Created logical/$old_ubuntu_tag pointing at HEAD"

    whatnow
}


review() {
    local new_debian new_ubuntu new_ubuntu_tag

    work_dir_clean
    descends_from new/debian

    new_debian=$(get_version new/debian)
    new_ubuntu=${new_debian}ubuntu1
    new_ubuntu_tag=$(version_to_tag "$new_ubuntu")

    git tag logical/"$new_ubuntu_tag"
    echo "Created logical/$new_ubuntu_tag pointing at HEAD"

    whatnow
}


finish() {
    local new_debian new_ubuntu new_ubuntu_tag merge_bug devel_name

    work_dir_clean
    descends_from new/debian

    merge_bug="$1"
    new_debian=$(get_version new/debian)
    new_ubuntu="$new_debian"ubuntu1
    new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
    devel_name=$(distro-info --devel)

    [ -z "${merge_bug}" ] && die "Missing merge bug!"

    tmpdir=$(mktemp -d /tmp/merge.XXXX)
    trap 'rm -fr -- "${tmpdir}"' EXIT

    echo "Merging changelogs"
    git cat-file blob old/debian:debian/changelog > "$tmpdir"/changelog.old.debian
    git cat-file blob old/ubuntu:debian/changelog > "$tmpdir"/changelog.old.ubuntu
    git cat-file blob new/debian:debian/changelog > "$tmpdir"/changelog.new.debian
    dpkg-mergechangelogs \
        "$tmpdir"/changelog.old.debian \
        "$tmpdir"/changelog.old.ubuntu \
        "$tmpdir"/changelog.new.debian > debian/changelog
    git commit debian/changelog -m merge-changelog
    debchange -i "Merge from Debian unstable (LP: #${merge_bug}). Remaining changes:" --distribution "$devel_name"
    debchange -a "Removed obsolete patches/changes:"
    debchange -a "Removed patches obsoleted/merged by upstream:"
    git log new/debian.. --topo-order --reverse --format="%B%n### END ###" | \
        "$MY_PATH"/mergedch.py > "$tmpdir"/changelog.insert
    sed -i -e "3r ${tmpdir}/changelog.insert" debian/changelog
    debchange -r
    echo "Updating maintainer"
    if update-maintainer; then
        git commit -m update-maintainer -- debian/control
    fi
    git commit -m reconstruct-changelog -- debian/changelog
    git tag merge/"$new_ubuntu_tag"
    echo "Created merge/$new_ubuntu_tag pointing at HEAD"

    whatnow "$merge_bug"
}


test_() {
    local project new_debian new_ubuntu new_ubuntu_tag devel_name devel_arch
    local chroot_name top_level parent logfile rc

    top_level=$(git rev-parse --show-toplevel)
    parent=$(dirname "${top_level}")
    project=$(get_project new/debian)
    new_debian=$(get_version new/debian)
    new_ubuntu=${new_debian}ubuntu1
    new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
    devel_name=$(distro-info --devel)
    devel_arch=$(dpkg-architecture -q DEB_HOST_ARCH)
    chroot_name="$devel_name-$devel_arch"
    logfile="${parent}/${project}_${new_ubuntu}.autopkgtest"

    work_dir_clean
    descends_from "merge/$new_ubuntu_tag"

    if ! schroot -l | grep "chroot:${chroot_name}" >/dev/null; then
        echo "Building the required schroot"
        mk-sbuild "$devel_name" >/dev/null
    fi
    echo "Testing in schroot $chroot_name"
    if autopkgtest -- schroot "$chroot_name" > "$logfile" 2>&1; then
        echo "Test passed"
        whatnow
    elif [ $? -eq 2 ]; then
        echo "Some tests skipped, but otherwise passed"
        whatnow
    else
        cat "$logfile"
        mv "$logfile" "${logfile}.fail"
        echo "Test(s) failed; log output above and stored in ${logfile}.fail"
        echo "Fix the package then re-run: merge test"
    fi
}


build() {
    local lpuser new_debian old_ubuntu old_ubuntu_tag new_ubuntu new_ubuntu_tag
    local project devel_name top_level parent debdiff merge_bug logfile

    top_level=$(git rev-parse --show-toplevel)
    parent=$(dirname "${top_level}")
    project=$(get_project new/debian)
    devel_name=$(distro-info --devel)
    lpuser=$(git config --get ubuntu.lpuser)
    new_debian=$(get_version new/debian)
    old_ubuntu=$(get_version old/ubuntu)
    old_ubuntu_tag=$(version_to_tag "$old_ubuntu")
    new_ubuntu=${new_debian}ubuntu1
    new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
    merge_bug=$(get_merge_bug merge/"$new_ubuntu_tag")
    debdiff="${parent}/1-${merge_bug}.debdiff"
    logfile="${parent}/${project}_${new_ubuntu}.sbuild"

    echo "Building source package for $devel_name"
    sbuild --dist "$devel_name" --no-arch-any --no-arch-all --source --force-orig-source > "$logfile"
    echo "Pushing tags"
    git push $lpuser --delete old/debian --delete new/debian
    git push $lpuser \
        tag old/debian \
        tag new/debian \
        tag logical/$old_ubuntu_tag \
        tag logical/$new_ubuntu_tag \
        tag merge/$new_ubuntu_tag
    echo "Generating debdiff"
    git diff new/debian merge/$new_ubuntu_tag > "$debdiff"

    whatnow
}


die() {
    echo "$@" >&2
    exit 1
}


work_dir_clean() {
    [ -z "$(git status --porcelain)" ] || die "Working directory not clean!"
}


descends_from() {
    local commitish="$1"

    if ! git merge-base --is-ancestor "$commitish" HEAD; then
        die "HEAD does not descend from $commitish!"
    fi
}


not_descends_from() {
    local commitish="$1"

    if git merge-base --is-ancestor "$commitish" HEAD; then
        die "HEAD descends from $commitish!"
    fi
}


get_project() {
    local commitish="$1"

    git cat-file blob "$commitish":debian/control | \
        sed -n -e '/^Source:/ s/.*: *//p'
}


get_version() {
    local commitish="$1"

    git cat-file blob "$commitish":debian/changelog | \
        head -n 1 | \
        sed -n -e 's/.*(//' -e 's/).*//p'
}


get_merge_bug() {
    local commitish="$1"

    git cat-file blob "$commitish":debian/changelog | \
        head -n 3 | \
        sed -n -e '/LP: #/ s,.*(LP: #\([0-9]\+\)).*,\1, p'
}


version_to_tag() {
    local version="$1"

    echo "$version" | perl -pe 'y/:~/%_/; s/\.(?=\.|$|lock$)/.#/g;'
}


tag_to_version() {
    local tag="$1"

    echo "$tag" | perl -pe 'y/%_/:~/; s/#//g;'
}


tag_exists() {
    local tag="$1"

    git rev-parse "$tag" -- >/dev/null 2>/dev/null
}


main "$@"
