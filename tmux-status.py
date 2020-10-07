#!/usr/bin/python3

import os
import math
import time
import pickle
import tempfile
import datetime as dt
import subprocess as sp
from pathlib import Path
from getpass import getuser
from functools import lru_cache


def format_decimal_size(size, suffixes=('B', 'kB', 'MB', 'GB', 'TB', 'PB'),
                        zero='0', template='{size:.0f}{suffix}'):
    try:
        index = min(len(suffixes) - 1, int(round(math.log(abs(size), 1000), 2)))
    except ValueError:
        return zero
    else:
        return template.format(size=(size / (1000 ** index)),
                               suffix=suffixes[index])


def format_binary_size(size, suffixes=('B', 'kB', 'MB', 'GB', 'TB', 'PB'),
                       zero='0', template='{size:.0f}{suffix}'):
    try:
        index = min(len(suffixes) - 1, int(round(math.log(abs(size), 2) / 10, 2)))
    except ValueError:
        return zero
    else:
        return template.format(size=(size / 2 ** (index * 10)),
                               suffix=suffixes[index])


def format_duration(seconds):
    days, rem = divmod(int(seconds), 86400)
    hours, rem = divmod(rem, 3600)
    if days:
        return f'{days:d}d{hours:d}h'
    else:
        mins, secs = divmod(rem, 60)
        if hours:
            return f'{hours:d}h{mins:d}m'
        elif mins:
            return f'{mins:d}m{secs:d}s'
        else:
            return f'{secs:d}s'


@lru_cache
def cache_dir():
    cache_root = Path('/dev/shm')
    user = getuser()
    prefix = f'tmux-{user}-'
    for d in cache_root.glob(prefix + '*'):
        if d.is_dir() and d.owner() == user:
            return d
    return Path(tempfile.mkdtemp(prefix=prefix, dir=cache_root))


class StaleError(ValueError):
    pass


class Stat:
    timeout = 15
    fg = 'white'
    bg = 'black'

    def __str__(self):
        return f'#[fg={self.fg},bg={self.bg}]{self.value or ""}#[default]'

    def _cache_file(self):
        return cache_dir() / f'{self.name}.cache'

    def _cached_value(self):
        path = self._cache_file()
        try:
            if time.time() > path.stat().st_mtime + self.timeout:
                raise StaleError()
        except FileNotFoundError:
            raise StaleError()
        with path.open('rb') as f:
            return pickle.load(f)

    def _raw_value(self):
        raise NotImplementedError

    def _format_value(self, value):
        raise NotImplementedError

    @property
    def value(self):
        try:
            value = self._cached_value()
        except StaleError:
            value = self._raw_value()
            with self._cache_file().open('wb') as f:
                pickle.dump(value, f)
        return self._format_value(value)


class UpdatesStat(Stat):
    name = 'updates'
    timeout = 59
    bg = 'red'

    def _format_value(self, value):
        return f'{value}!' if value else ''

    def _raw_value(self):
        cache_file = self._cache_file()
        pid = os.fork()
        if pid == 0:  # child fork
            temp_file = cache_file.with_suffix('.new')
            lock_file = cache_file.with_suffix('.lock')
            try:
                # This would be better done with flock but ... I'm lazy
                with lock_file.open('x'):
                    cmd = [
                        'apt-get',
                        '-s',
                        '-o', 'Debug::NoLocking=true',
                        'upgrade']
                    try:
                        result = sp.run(cmd, stdout=sp.PIPE,
                                        encoding='utf-8', check=True)
                    except sp.CalledProcessError:
                        pass
                    else:
                        count = sum(
                            1 for line in result.stdout.splitlines()
                            if line.startswith('Inst')
                        )
                        with temp_file.open('wb') as f:
                            pickle.dump(count, f)
                        temp_file.rename(cache_file)
            except FileExistsError:
                pass
            else:
                lock_file.unlink()
            finally:
                raise SystemExit(0)
        try:
            with cache_file.open('rb') as f:
                return pickle.load(f)
        except FileNotFoundError:
            return 0

    def _cached_value(self):
        cache_file = self._cache_file()
        source_files = {
            Path(d)
            for d in ('/var/lib/apt', '/var/lib/apt/lists', '/var/log/dpkg.log')
        }
        try:
            cache_stat = cache_file.stat()
        except FileNotFoundError:
            raise StaleError()
        else:
            if any(
                cache_stat.st_mtime < source.stat().st_mtime
                for source in source_files
            ):
                raise StaleError()
        with cache_file.open('rb') as f:
            return pickle.load(f)


class UptimeStat(Stat):
    name = 'uptime'
    timeout = 29
    fg = 'blue'
    bg = 'white'

    def _format_value(self, value):
        return format_duration(value)

    def _raw_value(self):
        with open('/proc/uptime') as f:
            up, idle = f.read().split()
        return float(up)


class LoadStat(Stat):
    name = 'loadavg'
    timeout = 2
    fg = 'black'
    bg = 'brightyellow'

    def _format_value(self, value):
        return f'{value:.2f}'

    def _raw_value(self):
        return os.getloadavg()[0]


class CPUTempStat(Stat):
    name = 'cputemp'
    timeout = 3
    fg = 'black'
    bg = 'red'

    def _format_value(self, value):
        return f'{value:.0f}°C'

    def _raw_value(self):
        with open('/sys/class/thermal/thermal_zone0/temp') as f:
            return int(f.read()) / 1000


class NetStat(Stat):
    name = 'network'
    timeout = 3
    fg = 'white'
    bg = 'magenta'

    def _format_value(self, value):
        up_count, up_diff, down_count, down_diff = value
        return f'↑{format_binary_size(diff)}'


class StorageStat(Stat):
    name = 'storage'
    timeout = 13
    fg = 'white'
    bg = 'black'

    def _format_value(self, value):
        total, used = value
        return f'{format_binary_size(total)}{used}%'


class MemStat(StorageStat):
    name = 'mem'
    bg = 'green'

    def _raw_value(self):
        values = {}
        labels = {'MemTotal:', 'MemAvailable:', 'MemFree:', 'Cached:'}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                label, value, units = line.split()
                if label in labels:
                    values[label] = int(value) * 1024
                    if {'MemTotal:', 'MemAvailable:'} <= values.keys():
                        total = values['MemTotal:']
                        free = values['MemAvailable:']
                        break
                    elif {'MemTotal:', 'MemFree:', 'Cached:'} <= values.keys():
                        total = values['MemTotal:']
                        free = values['MemFree:'] + values['Cached:']
                        break
            else:
                return ''
        used = 100 - int(free * 100 / total)
        return total, used


class SwapStat(StorageStat):
    name = 'swap'
    bg = 'cyan'

    def _raw_value(self):
        values = {}
        labels = {'SwapTotal:', 'SwapFree:'}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                label, value, units = line.split()
                if label in labels:
                    assert units == 'kB'
                    values[label] = int(value) * 1024
                    if {'SwapTotal:', 'SwapFree:'} == values.keys():
                        total = values['SwapTotal:']
                        free = values['SwapFree:']
                        break
            else:
                return ''
        used = 100 - int(free * 100 / total)
        return total, used


class DiskStat(StorageStat):
    name = 'disk'
    bg = 'magenta'

    def _raw_value(self, path='/'):
        stat = os.statvfs(path)
        total = stat.f_blocks * stat.f_frsize
        used = 100 - int(stat.f_bfree * 100 / stat.f_blocks)
        return total, used


if __name__ == '__main__':
    stats = (
        UpdatesStat(),
        UptimeStat(),
        CPUTempStat(),
        LoadStat(),
        MemStat(),
        SwapStat(),
        DiskStat(),
    )
    print(' '.join(str(stat) for stat in stats))
