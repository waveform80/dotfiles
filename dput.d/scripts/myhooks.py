# Adapted from
# https://git.launchpad.net/~ubuntu-server/+git/ubuntu-helpers/tree/cpaelzer/.dput.d/scripts/mymistakes.py

import re

from distro_info import UbuntuDistroInfo
from dput.exceptions import HookException
from colorzero import Color


red = Color('red')
yellow = Color('yellow')
green = Color('green')


def stop(message):
    raise HookException(f'{red}STOP{red:0}: {message}')


def warn(message):
    print(f'{yellow}WARNING{yellow:0}: {message}', flush=True)


def ask(interface, question, default="no"):
    return interface.boolean(
        title=f'{green}Check{green:0}',
        message=question, default=default)


email_re = re.compile(r'((?P<name>.+)\s*<)?(?P<email>\S+)(?(1)>|$)$')
def parse_email(s):
    """
    Parses (with a regex … yes, I know) an string containing either just an
    e-mail address or "name <e-mail>" into a name, e-mail tuple.
    """
    m = email_re.match(s)
    assert m
    return m.group('name'), m.group('email')


def check_for_ppa(changes, profile, interface):
    """
    If the version contains a ppa suffix that likely is not meant to be
    uploaded to the ubuntu archive.
    """
    version = changes['Version']
    version_contains_ppa = re.search(r'~ppa\d*$', version)

    if profile['fqdn'] == 'ppa.launchpad.net':
        if not version_contains_ppa:
            warn(f'PPA upload "{version}" has no ~ppa suffix')
            if not ask(interface, 'Upload without suffix?'):
                stop(f'PPA upload "{version}" has no ~ppa suffix')
    else:
        if version_contains_ppa:
            stop(f'archive upload "{version}" has a ~ppa suffix')


def bad_author(changes, profile, interface):
    """
    If built in a LXD or a VM bad emails might end up signing the upload.
    By sponsoring them you'd push these bad emails into the archive.
    """
    _, email = parse_email(changes['Changed-By'])
    if email.startswith(('ubuntu@', 'root@')):
        stop(f'Changed-By email "{email}" contains ubuntu@ or root@')


def check_bug_ref(changes, profile, interface):
    """
    Not always, but often it is wrong to upload without any bug reference.
    """
    if 'Launchpad-Bugs-Fixed' not in changes:
        warn('no bugs marked as closed')
        if not ask(interface, 'Upload without bug references?'):
            stop('no bugs referenced')


def check_update_maintainer(changes, profile, interface):
    """
    If the version mentions Ubuntu changes, most likely update-maintainer
    should have been run. This is similar to the check by dpkg-buildpkg.
    """
    version = changes['Version']
    if re.search(r'\dubuntu\d*$', version):
        _, email = parse_email(changes['Maintainer'])
        if not email.endswith('ubuntu.com'):
            warn(f'Upload without @ubuntu.com maintainer ({email})')
            if not ask(interface, 'Upload with bad maintainer?'):
                stop('bad maintainer')


def check_git_ubuntu(changes, profile, interface):
    """
    Check if the git-ubuntu Vcs-* entries are present, since most of our
    uploads in the Server Team are meant to go with those warn and ask if not.
    """
    # Urgh ... Changes lacks __iter__ so we can't just enumerate it ...
    missing = {'Vcs-Git', 'Vcs-Git-Commit', 'Vcs-Git-Ref'} - set(changes._data)
    if missing:
        for entry in missing:
            warn(f'.changes file does not contain git-ubuntu "{entry}"')
        if not ask(interface, 'Upload without git-ubuntu Vcs entries?'):
            stop('git-ubuntu Vcs entries missing')


def check_ubuntu_release(changes, profile, interface):
    """
    Check if one of the common backport suffixes like ...20.10... does not
    match the target release e.g. Focal which should be 20.04
    """
    version = changes['Version']
    ver_release = re.findall(r'(?<!\d)(\d\d\.\d\d)(?!\d)', version)
    if not ver_release:
        return
    # We're only interested in the last match as the XX.YY release is always
    # a suffix
    ver_release = ver_release[-1]

    info = UbuntuDistroInfo()
    # Strip pockets (-proposed, -updates, ...)
    codename, *_ = changes['Distribution'].split('-')
    dist_release = info.version(codename)
    # LTS versions are represented as, for example, "20.04 LTS"
    if dist_release.endswith(' LTS'):
        dist_release = dist_release[:-4]

    if ver_release != dist_release:
        warn(f'Version {version} contains {ver_release} which does not match '
             f"{codename}'s {dist_release}")
        if not ask(interface, 'Upload with mismatched release?'):
            stop(f'{ver_release} does not match target {dist_release}')
