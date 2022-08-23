#!/bin/bash
# vim: set noet sw=4 sts=4:

set -eu
MY_PATH=$(dirname "$(readlink -f "$0")")
MSG="[0;33m"
COMMENT="[0;32m"
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
			shift
			start_ "$@"
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
		rebased)
			shift
			rebased "$@"
			;;
		test)
			shift
			if [ "${1:-}" = "--vm" ]; then
				test_qemu
			else
				test_schroot
			fi
			;;
		build)
			build
			;;
		finish)
			finish
			;;
		push)
			push
			;;
		whatnow|help|--help|-h)
			shift
			whatnow "$@"
			;;
		*)
			echo "Usage:" "$(basename "$0")" "whatnow"
			exit 1
			;;
	esac
	exit 0
}


whatnow() {
	echo -n "$MSG"
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
		local old_debian new_debian
		local old_ubuntu ubuntu_devel old_ubuntu_tag
		local new_ubuntu new_ubuntu_tag
		local autopkgtest_dir autopkgtest_run source_changes deb_diff
		local merge_bug lpuser

		lpuser=$(git config --get ubuntu.lpuser)
		top_level=$(git rev-parse --show-toplevel)
		parent=$(dirname "${top_level}")
		project=$(get_project new/debian)
		old_debian=$(get_version old/debian)
		new_debian=$(get_version new/debian)
		old_ubuntu=$(get_version old/ubuntu)
		ubuntu_devel=$(get_version origin/ubuntu/devel)
		old_ubuntu_tag=$(version_to_tag "$old_ubuntu")
		new_ubuntu=${new_debian}ubuntu1
		new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
		autopkgtest_dir="${parent}/${project}_${new_ubuntu}.autopkgtest"
		build_log="${parent}/${project}_${new_ubuntu}.sbuild"
		source_changes="${parent}/${project}_${new_ubuntu}_source.changes"
		merge_bug=$(get_merge_bug merge/"$new_ubuntu_tag")
		[ -z "$merge_bug" ] && merge_bug=$(get_merge_bug candidate/"$new_ubuntu_tag")
		[ -z "$merge_bug" ] && merge_bug="${1:-}"
		[ -z "$merge_bug" ] && merge_bug="MERGE_BUG"
		deb_diff=$(get_deb_diff "$parent" "$merge_bug" 1)

		if [ "$old_ubuntu" != "$ubuntu_devel" ] || ! tag_exists start/"$old_ubuntu_tag"; then
			cat <<- EOF
			Start the merge with:
			$RESET
			\$ merge start [branch-name] $COMMENT# defaults to debian/sid
			EOF
		elif ! tag_exists split/"$old_ubuntu_tag"; then
			cat <<- EOF
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
			cat <<- EOF
			Construct a "clean" set of changes by removing redundant or upstreamed changes.
			Also remove all "metadata" and "changelog" commits (these will be added back
			in later):
			$RESET
			\$ git rebase -i old/debian # and remove redundant commits
			\$ merge logical
			EOF
		elif ! tag_exists logical/"$new_ubuntu_tag"; then
			cat <<- EOF
			Rebase the "clean" set of changes onto new/debian and review with:
			$RESET
			\$ git rebase --onto new/debian old/debian logical/$old_ubuntu_tag
			\$ merge review
			EOF
		elif ! tag_exists candidate/"$new_ubuntu_tag"; then
			cat <<- EOF
			Review the changes, open a merge bug on Launchpad, then reconstruct changelogs
			and complete the rebase with:
			$RESET
			\$ git range-diff old/debian..logical/$old_ubuntu_tag new/debian..logical/$new_ubuntu_tag
			\$ www-browser ${LINK}http://pad.lv/fb/u/$project${RESET}
			\$ merge rebased \$merge_bug
			$MSG
			Bug template:
			$TEMPLATE
			Please merge $project $new_debian from Debian unstable.

			Updated changelog and diff against Debian unstable to be attached below.
			EOF
		elif ! [ -d "$autopkgtest_dir" ] || [ -e "${autopkgtest_dir}/fail" ]; then
			if [ -d "$top_level"/debian/tests ]; then
				if [ -e "${autopkgtest_dir}/fail" ]; then
					autopkgtest_run=$(cat "${autopkgtest_dir}/fail")
					cat <<- EOF
					Test(s) failed; log output stored in:
					${autopkgtest_dir}/${autopkgtest_run}
					Fix the package then re-run:
					$RESET
					\$ merge test [--vm]
					EOF
				else
					cat <<- EOF
					Run autopkgtest on your merged package:
					$RESET
					\$ merge test [--vm]
					EOF
				fi
			else
				echo "No tests available"
				mkdir -p "$autopkgtest_dir"
				whatnow
			fi
		elif ! [ -e "$build_log" ] && ! [ -e "$source_changes" ]; then
			if [ -e "${build_log}.fail" ]; then
				cat <<- EOF
				Build failed; log output stored in ${build_log}.fail
				Fix the package then re-run:
				EOF
			else
				cat <<- EOF
				Build a source package:
				EOF
			fi
			cat <<- EOF
			$RESET
			\$ merge build
			EOF
		elif ! tag_exists merge/"$new_ubuntu_tag" || ! [ -e "$deb_diff" ]; then
			cat <<- EOF
			Finalize the merge and generate the debdiff:
			$RESET
			\$ merge finish
			EOF
		elif [ -z "$(git ls-remote --tags "$lpuser" merge/"$new_ubuntu_tag" 2>/dev/null)" ]; then
			cat <<- EOF
			Publish the changes to your clone of the repo on Launchpad:
			$RESET
			\$ merge push
			EOF
		else
			cat <<- EOF
			Attach $deb_diff
			to ${LINK}LP: #$merge_bug${MSG} with something like the following message,
			and subscribe ubuntu-sponsors:
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
	echo -n "$RESET"
}


clone() {
	local project lpuser lpprefix

	project="$1"
	lpuser=$(git config --get ubuntu.lpuser)
	lpprefix="git+ssh://$lpuser@git.launchpad.net"
	urls=( \
		"$lpprefix"/ubuntu/+source/"$project" \
		"$lpprefix"/~git-ubuntu-import/ubuntu/+source/"$project" \
	)

	for url in "${urls[@]}"; do
		git clone "$url" "$project" || continue
		break
	done
	pushd "$project"
	git remote add "$lpuser" "$lpprefix"/~"$lpuser"/ubuntu/+source/"$project"
	popd

	whatnow "$project"
}


start_() {
	local merge_base merge_target old_ubuntu old_ubuntu_tag new_debian old_debian

	work_dir_clean

	echo "Fetching origin"
	git fetch origin

	merge_target="${1:-origin/debian/sid}"
	merge_base=$(git merge-base "$merge_target" origin/ubuntu/devel)
	old_ubuntu=$(get_version origin/ubuntu/devel)
	old_ubuntu_tag=$(version_to_tag "$old_ubuntu")
	new_debian=$(get_version "$merge_target")
	old_debian=$(get_version "$merge_base")

	[ "${old_debian}" = "${new_debian}" ] && \
		die "Current version is based on Debian unstable!"

	git checkout "$merge_target" 2>/dev/null
	echo "Removing old tags and branches"
	git tag -d old/ubuntu old/debian new/debian 2>/dev/null || true
	git branch -D split logical merge 2>/dev/null || true
	echo "Refreshing stale branches"
	git branch -D ubuntu/devel 2>/dev/null || true
	if git show-ref --heads "${merge_target#origin/}" >/dev/null; then
		git branch -D "${merge_target#origin/}" 2>/dev/null || true
	fi

	echo "Creating new tags and branches:"
	git tag old/ubuntu origin/ubuntu/devel
	echo "	old/ubuntu (tag) pointing at import/${old_ubuntu}"
	git tag old/debian "$merge_base"
	echo "	old/debian (tag) pointing at import/${old_debian}"
	git tag new/debian "$merge_target"
	echo "	new/debian (tag) pointing at import/${new_debian}"
	tag_exists start/"$old_ubuntu_tag" || git tag start/"$old_ubuntu_tag" old/ubuntu
	if tag_exists split/"$old_ubuntu_tag"; then
		echo "	split (branch) pointing at split/$old_ubuntu_tag"
		git branch split split/"$old_ubuntu_tag"
		if tag_exists logical/"$old_ubuntu_tag"; then
			echo "	logical (branch) pointing at logical/$old_ubuntu_tag"
			git branch logical logical/"$old_ubuntu_tag"
			git checkout logical
		else
			git checkout split
		fi
	else
		echo "	split (branch) pointing at old/ubuntu"
		git branch split old/ubuntu
		git checkout split
	fi

	whatnow
}


split() {
	local old_debian old_ubuntu old_ubuntu_tag

	work_dir_clean
	descends_from old/debian
	not_descends_from new/debian
	[ -z "$(git diff old/ubuntu)" ] || die "Split does not match old/ubuntu!"

	old_debian=$(get_version old/debian)
	old_ubuntu=$(get_version old/ubuntu)
	old_ubuntu_tag=$(version_to_tag "$old_ubuntu")

	echo "Creating new tags and branches:"
	git tag split/"$old_ubuntu_tag"
	echo "	split/$old_ubuntu_tag (tag) pointing at HEAD"
	git checkout -b logical
	echo "	logical (branch) potining at HEAD"

	whatnow
}


logical() {
	local old_ubuntu old_ubuntu_tag force

	force=0
	case "${1:-}" in
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

	echo "Creating new tags and branches:"
	git tag logical/"$old_ubuntu_tag"
	echo "	logical/$old_ubuntu_tag (tag) pointing at HEAD"
	git checkout -b merge
	echo "	merge pointing at HEAD"

	whatnow
}


review() {
	local new_debian new_ubuntu new_ubuntu_tag

	work_dir_clean
	descends_from new/debian
	patches_apply

	new_debian=$(get_version new/debian)
	new_ubuntu=${new_debian}ubuntu1
	new_ubuntu_tag=$(version_to_tag "$new_ubuntu")

	git tag logical/"$new_ubuntu_tag"
	echo "Created logical/$new_ubuntu_tag pointing at HEAD"

	whatnow
}


rebased() {
	local new_debian new_ubuntu new_ubuntu_tag merge_bug devel_name

	work_dir_clean
	descends_from new/debian
	patches_apply

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
		git commit -m metadata -- debian/control
	fi
	git commit -m reconstruct-changelog -- debian/changelog
	git tag candidate/"$new_ubuntu_tag"
	echo "Created candidate/$new_ubuntu_tag pointing at HEAD"

	whatnow
}


test_schroot() {
	local project new_debian new_ubuntu new_ubuntu_tag devel_name devel_arch
	local chroot_name top_level parent log_dir log_num rc

	top_level=$(git rev-parse --show-toplevel)
	parent=$(dirname "${top_level}")
	project=$(get_project new/debian)
	new_debian=$(get_version new/debian)
	new_ubuntu=${new_debian}ubuntu1
	new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
	devel_name=$(distro-info --devel)
	devel_arch=$(dpkg-architecture -q DEB_HOST_ARCH)
	chroot_name="$devel_name-$devel_arch"
	log_dir="${parent}/${project}_${new_ubuntu}.autopkgtest"
	log_num=1

	work_dir_clean
	descends_from new/debian
	fix_tag "candidate/$new_ubuntu_tag"
	descends_from "candidate/$new_ubuntu_tag"

	if ! schroot -l | grep "chroot:${chroot_name}" >/dev/null; then
		echo "Building the required schroot"
		mk-sbuild "$devel_name" >/dev/null
	fi
	echo "Testing in schroot $chroot_name"

	mkdir -p "$log_dir"
	while [ -d "$log_dir/run-$log_num" ]; do
		log_num=$((log_num + 1))
	done
	rc=0
	autopkgtest . -o "$log_dir/run-$log_num" -- \
		schroot "$chroot_name" >/dev/null 2>&1 || rc=$?
	test_post "$log_dir" "$log_num" "$rc"
}


test_qemu() {
	local project new_debian new_ubuntu new_ubuntu_tag devel_name devel_arch
	local image_name top_level parent log_dir log_num rc

	top_level=$(git rev-parse --show-toplevel)
	parent=$(dirname "${top_level}")
	project=$(get_project new/debian)
	new_debian=$(get_version new/debian)
	new_ubuntu=${new_debian}ubuntu1
	new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
	devel_name=$(distro-info --devel)
	devel_arch=$(dpkg-architecture -q DEB_HOST_ARCH)
	chroot_name="$devel_name-$devel_arch"
	log_dir="${parent}/${project}_${new_ubuntu}.autopkgtest"
	log_num=1
	image_name="${log_dir}/autopkgtest-${devel_name}-${devel_arch}.img"

	work_dir_clean
	descends_from new/debian
	fix_tag "candidate/$new_ubuntu_tag"
	descends_from "candidate/$new_ubuntu_tag"

	mkdir -p "$log_dir"
	if ! [ -e "$image_name" ]; then
		echo "Building image $image_name"
		autopkgtest-buildvm-ubuntu-cloud \
			--release="$devel_name" \
			--arch="$devel_arch" \
			--output-dir="$log_dir" >/dev/null 2>&1
	fi
	echo "Testing with image $image_name"

	while [ -d "$log_dir/run-$log_num" ]; do
		log_num=$((log_num + 1))
	done
	rc=0
	autopkgtest . -o "$log_dir/run-$log_num" -- \
		qemu "$image_name" >/dev/null 2>&1 || rc=$?
	test_post "$log_dir" "$log_num" "$rc"
}


test_post() {
	local log_dir log_num rc

	log_dir="$1"
	log_num="$2"
	rc="$3"

	if [ "$rc" -eq 0 ]; then
		rm -f "$log_dir/fail"
		echo "Test passed"
	elif [ "$rc" -eq 2 ]; then
		rm -f "$log_dir/fail"
		echo "Some tests skipped, but otherwise passed"
		echo
		cat "$log_dir/run-$log_num/summary"
	elif [ "$rc" -eq 8 ]; then
		rm -f "$log_dir/fail"
		echo "All tests skipped; check output in:"
		echo "$log_dir/run-$log_num/"
		echo
		cat "$log_dir/run-$log_num/summary"
	else
		echo "Tests failed; see output in:"
		echo "$log_dir/run-$log_num"
		echo
		echo "run-$log_num" > "$log_dir/fail"
		cat "$log_dir/run-$log_num/summary"
	fi
	whatnow
}


build() {
	local new_debian new_ubuntu new_ubuntu_tag project devel_name top_level
	local parent log_file upstream orig_tar deb_format tarball rev_count

	top_level=$(git rev-parse --show-toplevel)
	deb_format=$(git cat-file blob HEAD:debian/source/format)
	parent=$(dirname "${top_level}")
	project=$(get_project new/debian)
	devel_name=$(distro-info --devel)
	new_debian=$(get_version new/debian)
	upstream=$(strip_debian_version "$new_debian")
	new_ubuntu=${new_debian}ubuntu1
	new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
	log_file="${parent}/${project}_${new_ubuntu}.sbuild"

	work_dir_clean
	descends_from new/debian
	fix_tag "candidate/$new_ubuntu_tag"
	descends_from "candidate/$new_ubuntu_tag"

	if [ "$deb_format" = "3.0 (quilt)" ]; then
		echo "Extracting orig tar-ball for ${project} ${upstream}"
		if git show-ref --heads pristine-tar >/dev/null; then
			rev_count="$( \
				git rev-list --left-right --count \
				pristine-tar..origin/importer/debian/pristine-tar)"
			if [ "$rev_count" != $'0\t0' ]; then
				git branch -D pristine-tar
			fi
		fi
		if ! git show-ref --heads pristine-tar >/dev/null; then
			git branch --track pristine-tar origin/importer/debian/pristine-tar
		fi
		orig_tar="$(pristine-tar list | grep -F "${project}_${upstream}" || true)"
		if [ -z "$orig_tar" ]; then
			echo "No ${project}_${upstream} tar-ball found in pristine-tar!"
			echo "Attempting Debian source download..."
			orig_tar="$( \
				pull-debian-source --pull=list "$project" "$new_debian" 2>&1 \
				| grep "\.orig\.tar")"
			for tarball in $orig_tar; do
				if [ -e "$parent"/"$tarball" ]; then
					continue
				else
					pushd "$parent"
					pull-debian-source --download-only "$project" "$new_debian"
					popd
					break
				fi
			done
		else
			for tarball in $orig_tar; do
				if ! [ -e "$parent"/"$tarball" ]; then
					pristine-tar checkout "$parent"/"$tarball"
				fi
			done
		fi
	fi

	echo "Building source package for $devel_name"
	if sbuild --dist "$devel_name" \
		--no-arch-any --no-arch-all --source \
		--force-orig-source > "$log_file" 2>&1
	then
		rm -f "${log_file}.fail"
		whatnow
	else
		cat "$log_file"
		mv "$log_file" "${log_file}.fail"
		whatnow
	fi
}

finish() {
	local top_level parent new_debian new_ubuntu new_ubuntu_tag merge_bug
	local deb_diff

	top_level=$(git rev-parse --show-toplevel)
	parent=$(dirname "${top_level}")
	new_debian=$(get_version new/debian)
	new_ubuntu=${new_debian}ubuntu1
	new_ubuntu_tag=$(version_to_tag "$new_ubuntu")
	merge_bug=$(get_merge_bug candidate/"$new_ubuntu_tag")
	deb_diff=$(get_deb_diff "$parent" "$merge_bug")

	work_dir_clean
	descends_from "candidate/$new_ubuntu_tag"

	git tag merge/"$new_ubuntu_tag"
	echo "Created merge/$new_ubuntu_tag pointing at HEAD"

	echo "Generating debdiff"
	git diff new/debian merge/"$new_ubuntu_tag" > "$deb_diff"

	whatnow
}


push() {
	local lpuser new_debian old_ubuntu old_ubuntu_tag new_ubuntu new_ubuntu_tag
	local project

	project=$(get_project new/debian)
	lpuser=$(git config --get ubuntu.lpuser)
	new_debian=$(get_version new/debian)
	old_ubuntu=$(get_version old/ubuntu)
	old_ubuntu_tag=$(version_to_tag "$old_ubuntu")
	new_ubuntu=${new_debian}ubuntu1
	new_ubuntu_tag=$(version_to_tag "$new_ubuntu")

	echo "Removing obsolete tags and branches"
	for name in split logical merge "tag old/debian" "tag new/debian"; do
		git push "$lpuser" --delete $name >/dev/null 2>&1 || true
	done
	echo "Pushing tags"
	git push "$lpuser" \
		split \
		logical \
		merge \
		tag old/debian \
		tag new/debian \
		tag split/"$old_ubuntu_tag" \
		tag logical/"$old_ubuntu_tag" \
		tag logical/"$new_ubuntu_tag" \
		tag merge/"$new_ubuntu_tag"

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


is_exactly() {
	local commitish="$1"

	git merge-base --is-ancestor "$commitish" HEAD && \
		git merge-base --is-ancestor HEAD "$commitish"
}


patches_apply() {
	local top_level deb_format result

	top_level=$(git rev-parse --show-toplevel)
	deb_format="$(cat "$top_level"/debian/source/format)"
	result=0

	if [ "$deb_format" = "3.0 (quilt)" ] && [ -s "$top_level"/debian/patches/series ]; then
		echo "Checking patches apply cleanly"
		pushd "$top_level" >/dev/null
		if ! QUILT_PATCHES="debian/patches" quilt push -a --fuzz=0 >/dev/null 2>&1; then
			if QUILT_PATCHES="debian/patches" quilt push -a --fuzz=2 >/dev/null 2>&1; then
				echo "Patches have fuzz; refresh required"
			else
				echo "Patches have conflicts; refresh required"
			fi
			result=1
		fi
		QUILT_PATCHES="debian/patches" quilt pop -a >/dev/null 2>&1
		rm -rf .pc/
		popd >/dev/null
	fi
	return $result
}


fix_tag() {
	local tag="$1"

	if ! git merge-base --is-ancestor "$tag" HEAD; then
		echo "HEAD does not descend from $tag"
	elif ! git merge-base --is-ancestor HEAD "$tag"; then
		echo "HEAD descends from $tag but has more commits"
	else
		return 0
	fi
	if confirm "Move $tag to HEAD? [y/N] "; then
		git tag -d "$tag"
		git tag "$tag"
	else
		return 1
	fi
}


confirm() {
	local result

	read -r -p "$@" result
	[ "${result,,}" = "y" ]
}


get_project() {
	local commitish="$1"

	git cat-file blob "$commitish":debian/control 2>/dev/null | \
		sed -n -e '/^Source:/ s/.*: *//p'
}


get_version() {
	local commitish="$1"

	git cat-file blob "$commitish":debian/changelog 2>/dev/null  | \
		head -n 1 | \
		sed -n -e 's/.*(//' -e 's/).*//p'
}


get_deb_diff() {
	local parent="$1"
	local merge_bug="$2"
	local existing="${3:-0}"
	local prefix name

	prefix=1
	while [ -e "${parent}/${prefix}-${merge_bug}.debdiff" ]; do
		prefix=$((prefix + 1))
	done
	if [ "$existing" -eq 1 -a "$prefix" -gt 1 ]; then
		prefix=$((prefix - 1))
	fi
	echo "${parent}/${prefix}-${merge_bug}.debdiff"
}


strip_debian_version() {
	local version="$1"

	# No, I can't replace it with ${var/search/replace}
	# shellcheck disable=SC2001
	echo "$version" | sed -e 's/-[^-]*$//'
}


get_merge_bug() {
	local commitish="$1"

	git cat-file blob "$commitish":debian/changelog 2>/dev/null | \
		head -n 10 | \
		sed -n -e '/LP: #/ s,.*(LP: #\([0-9]\+\)).*,\1, p' | \
		head -n 1
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
