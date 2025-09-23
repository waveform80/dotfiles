#!/usr/bin/python3

import os
import math
import time
import struct
import tempfile
import datetime as dt
import subprocess as sp
from pathlib import Path
from getpass import getuser
from functools import lru_cache
from itertools import tee

import cbor2


def pairwise(it):
    a, b = tee(it)
    next(b, None)
    return zip(a, b)


def bar(value):
    bars = ' ▁▂▃▄▅▆▇█'
    value = max(0, min(len(bars) - 1, (len(bars) * int(value)) // 100))
    return bars[value]


def percent(value, min_value, max_value):
    return int(100 * (value - min_value) / (max_value - min_value))


def format_decimal_size(size, suffixes=('', 'k', 'M', 'G', 'T', 'P'),
                        zero='0', template='{size:.0f}{suffix}'):
    try:
        index = min(len(suffixes) - 1, int(round(math.log(abs(size), 1000), 2)))
    except ValueError:
        return zero
    else:
        return template.format(size=(size / (1000 ** index)),
                               suffix=suffixes[index])


def format_binary_size(size, suffixes=('', 'k', 'M', 'G', 'T', 'P'),
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


@lru_cache(maxsize=1)
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
    fg = 'brightwhite'
    bg = 'black'

    def __str__(self):
        try:
            try:
                value = self._cached_value()
            except StaleError:
                value = self._raw_value()
                with self._cache_file().open('wb') as f:
                    cbor2.dump(value, f)
        except ValueError:
            return ''
        return self._format_value(value)

    def _cache_file(self):
        return cache_dir() / f'{self.name}.cbor'

    def _cached_value(self):
        path = self._cache_file()
        try:
            if time.time() > path.stat().st_mtime + self.timeout:
                raise StaleError()
        except FileNotFoundError:
            raise StaleError()
        with path.open('rb') as f:
            return cbor2.load(f)

    def _raw_value(self):
        raise NotImplementedError

    def _format_value(self, value):
        if value:
            prefix = suffix = ' '
            return (
                f'#[fg={self.bg}]#[fg={self.fg},bg={self.bg}]'
                f'{prefix}{value or ""}{suffix}'
            )
        else:
            return ''


class UpdatesStat(Stat):
    name = 'updates'
    timeout = 59
    bg = 'red'

    def _format_value(self, value):
        return super()._format_value(f'#[bright]{value}#[nobright]!' if value else '')

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
                            cbor2.dump(count, f)
                        temp_file.rename(cache_file)
            except FileExistsError:
                pass
            else:
                lock_file.unlink()
            finally:
                raise SystemExit(0)
        try:
            with cache_file.open('rb') as f:
                return cbor2.load(f)
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
            if dt.datetime.now().timestamp() - cache_stat.st_mtime > self.timeout:
                raise StaleError()
        with cache_file.open('rb') as f:
            return cbor2.load(f)


class UptimeStat(Stat):
    name = 'uptime'
    timeout = 29
    fg = 'blue'
    bg = 'white'

    def _format_value(self, value):
        return super()._format_value(format_duration(value))

    def _raw_value(self):
        with open('/proc/uptime') as f:
            up, idle = f.read().split()
        return float(up)


class LoadStat(Stat):
    name = 'loadavg'
    timeout = 2
    fg = 'black'
    bg = 'green'

    def _format_value(self, value):
        pct = percent(value, 0, os.cpu_count())
        return super()._format_value(f'{value:.2f}{bar(pct)}')

    def _raw_value(self):
        return os.getloadavg()[0]


class CPUTempStat(Stat):
    name = 'cputemp'
    timeout = 3
    fg = 'black'
    bg = '#ffdd00'

    def _format_value(self, value):
        return super()._format_value(f'{value:.0f}°C')

    def _raw_value(self):
        for path in Path('/sys/class/thermal').glob('thermal_zone*'):
            try:
                if (path / 'type').read_text().rstrip() in ('TCPU', 'cpu-thermal'):
                    return int((path / 'temp').read_text()) / 1000
            except FileNotFoundError:
                pass
        raise ValueError('no thermal zone')


class LaptopBatteryStat(Stat):
    name = 'laptop_battery'
    timeout = 31
    fg = 'white'
    bg = '#ff6600'

    def _format_value(self, value):
        volts, capacity = value
        return super()._format_value(f'{volts:.1f}V#[bright]{bar(capacity)}#[nobright]')

    def _raw_value(self):
        bat_path = Path('/sys/class/power_supply/BAT1')
        try:
            capacity = int((bat_path / 'capacity').read_text())
            volts = int((bat_path / 'voltage_now').read_text()) / 1_000_000
        except FileNotFoundError:
            raise ValueError('no battery found')
        return volts, capacity


class PiBatteryStat(Stat):
    name = 'pi_battery'
    timeout = 31
    fg = 'brightwhite'
    bg = '#ff6600'
    addr = 0x36
    scale = 78.125 / 1_000_000
    cap_volts = {
        # Current values from discharge curve of Samsung 35E cells
        # %cap volts
        100:   4.2,
        90.9:  4.07,
        81.8:  4.05,
        72.7:  3.96,
        63.6:  3.89,
        54.5:  3.8,
        45.5:  3.74,
        36.4:  3.66,
        27.3:  3.6,
        18.2:  3.51,
        9.1:   3.42,
        0:     3.21,
    }

    @classmethod
    def _convert_volts(cls, v):
        for (hi_cap, hi_v), (lo_cap, lo_v) in pairwise(cls.cap_volts.items()):
            if v > hi_v:
                return hi_cap
            elif v > lo_v:
                return lo_cap + ((v - lo_v) / (hi_v - lo_v)) * (hi_cap - lo_cap)
        return lo_cap

    def _format_value(self, value):
        volts, capacity = value
        return super()._format_value(f'{volts:.1f}V{bar(capacity)}')

    def _raw_value(self):
        try:
            from smbus import SMBus
        except ImportError:
            try:
                from smbus2 import SMBus
            except ImportError:
                raise ValueError('no I2C module')
        try:
            bus = SMBus(1)
        except OSError:
            raise ValueError('no I2C bus')
        try:
            try:
                chip = bus.read_byte(self.addr)
            except OSError:
                raise ValueError('no battery chip found')
            value = bus.read_word_data(self.addr, 2)
            # Byte-swap big-endian value
            value, = struct.unpack('<H', struct.pack('>H', value))
            volts = value * self.scale
            cap = self._convert_volts(volts)
            now = dt.datetime.now()
            with (Path.home() / 'bat.out').open('a') as f:
                f.write(f'{now:%Y-%m-%d %H:%M:%S},{volts},{cap}\n')
            return volts, self._convert_volts(volts)
        finally:
            bus.close()


class NetStat(Stat):
    name = 'network'
    timeout = 3
    fg = 'white'
    bg = 'magenta'

    def _format_value(self, value):
        up_count, up_diff, down_count, down_diff = value
        return super()._format_value(f'↑{format_binary_size(diff)}')


class StorageStat(Stat):
    name = 'storage'
    timeout = 13
    fg = 'brightwhite'
    bg = 'black'

    def _format_value(self, value):
        total, used = value
        return super()._format_value(f'{format_binary_size(total)}{bar(used)}')


class MemStat(StorageStat):
    name = 'mem'
    fg = 'black'
    bg = 'cyan'

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
                raise ValueError('MemFree and MemTotal not found')
        if not total:
            raise ValueError('no memory found?!')
        return total, 100 - percent(free, 0, total)


class SwapStat(StorageStat):
    name = 'swap'
    bg = 'brightblue'

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
                raise ValueError('SwapTotal and SwapFree not found')
        if not total:
            raise ValueError('no swap found')
        return total, 100 - percent(free, 0, total)


class DiskStat(StorageStat):
    name = 'disk'
    bg = 'magenta'

    def _raw_value(self, path='/'):
        stat = os.statvfs(path)
        total = stat.f_blocks * stat.f_frsize
        if not stat.f_blocks:
            raise ValueError('root file-system is 0 blocks big?!')
        return total, 100 - percent(stat.f_bfree, 0, stat.f_blocks)


if __name__ == '__main__':
    stats = (
        UpdatesStat(),
        LaptopBatteryStat(),
        PiBatteryStat(),
        CPUTempStat(),
        LoadStat(),
        MemStat(),
        SwapStat(),
        DiskStat(),
    )
    s = ''.join(str(stat) for stat in stats)
    s += f'#[default,fg={stats[-1].bg},reverse]#[default]'
    print(s)
