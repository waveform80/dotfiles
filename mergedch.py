#!/usr/bin/python3

import re
import sys
import argparse
from textwrap import dedent, wrap


def split_entries(source, delimiter='### END ###'):
    entry = []
    for line in source:
        line = line.rstrip()
        if line == delimiter:
            if entry:
                yield entry
            entry = []
        else:
            entry.append(line)
    if entry:
        yield entry


def filter_items(entry, tags=('*', '+', '-')):
    tags = tuple(tags)
    bugs_re = re.compile(' *(\()?LP: *#\d+(?(1)\)|)')
    for line in entry:
        if line.strip():
            if line.lstrip().startswith(tags):
                yield bugs_re.sub(line, '')
            elif line.startswith(' '):
                yield bugs_re.sub(line, '')
            else:
                pass


def split_items(entry, tags=('*', '+', '-')):

    def make_item():
        if lines:
            indent = len(lines[0]) - len(lines[0].lstrip())
            lines[0] = lines[0].lstrip(strip_chars)
            yield indent, ' '.join(lines)

    tags = tuple(tags)
    strip_chars = ''.join(tags + (' ', '\t'))
    lines = []
    entry = dedent('\n'.join(entry))
    for line in entry.splitlines():
        if line.lstrip().startswith(tags):
            yield from make_item()
            lines = [line]
        elif line.startswith(' '):
            lines.append(line.strip())
        else:
            assert False
    yield from make_item()


def format_item(item, bullet='-', indent=0, width=78):
    yield from wrap(
        item, width=width,
        initial_indent=' ' * indent + bullet + ' ',
        subsequent_indent=' ' * (indent + len(bullet) + 1))


def main(args=None):
    if args is None:
        args = sys.argv[1:]

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-w', '--width', type=int, metavar='CHARS', default=78,
        help="The width to which to wrap the output. Default: %(default)s")
    parser.add_argument(
        '-b', '--bullet', type=str, metavar='CHAR', default='-',
        help="The character to use to replace all bullet-point characters. "
        "Default: %(default)r")
    parser.add_argument(
        '-i', '--indent', type=int, metavar='CHARS', default=4,
        help="The number of spaces to indent all output. Default: %(default)s")
    parser.add_argument(
        '-s', '--separator', type=str, metavar='STR', default='### END ###',
        help="The string used to terminate each commit log message. Default: "
        "%(default)r")
    parser.add_argument(
        'source', type=argparse.FileType('r'), nargs='?', default=sys.stdin,
        help="The source of commit messages to parse and format. Defaults to "
        "stdin if not specified")
    config = parser.parse_args(args)

    for entry in split_entries(config.source, config.separator):
        for indent, item in split_items(filter_items(entry)):
            for line in format_item(item, bullet=config.bullet,
                                    indent=config.indent + indent,
                                    width=config.width):
                sys.stdout.write(line)
                sys.stdout.write('\n')


if __name__ == '__main__':
    main()
