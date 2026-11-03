#!/usr/bin/env python3
"""Prepare mono Vorbis ambience from the credited original recordings (requires ffmpeg)."""
import argparse
from array import array
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
FFMPEG = os.environ.get("FFMPEG_BIN", "ffmpeg")


def decode(path):
    data = subprocess.check_output([FFMPEG, '-v', 'error', '-i', str(path), '-ac', '1',
                                    '-ar', str(RATE), '-f', 'f32le', '-'])
    samples = array('f'); samples.frombytes(data)
    return samples


def normalize(samples, peak):
    dc = sum(samples) / len(samples)
    maximum = max(abs(x - dc) for x in samples) or 1
    return array('f', ((x - dc) * peak / maximum for x in samples))


def periodic(samples, seconds=1):
    count = min(RATE * seconds, len(samples) // 4)
    middle = array('f', samples[count:-count])
    for i in range(count):
        fraction = i / (count - 1)
        middle.append(samples[-count + i] * (1 - fraction) + samples[i] * fraction)
    return middle


def encode(samples, path):
    subprocess.run([FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ac', '1', '-ar', str(RATE),
                    '-i', '-', '-c:a', 'libvorbis', '-q:a', '3', str(path)],
                   input=samples.tobytes(), check=True)
    return dict(file=path.name, rate=RATE, channels=1, seconds=round(len(samples) / RATE, 3),
                bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    args = parser.parse_args(); source = args.sources
    output = ROOT / 'assets/audio/ambient'; output.mkdir(parents=True, exist_ok=True)
    waves = array('f')
    for name in ['wave1.flac', 'wave2.flac', 'wave3.flac', 'wave2.flac', 'wave1.flac', 'wave3.flac', 'wave1.flac', 'wave3.flac', 'wave2.flac', 'wave3.flac', 'wave1.flac', 'wave2.flac']:
        piece = normalize(decode(source / name), .34)
        # Crossfade the recordings rather than leaving abrupt recording boundaries.
        if waves:
            count = min(RATE // 2, len(piece), len(waves))
            for i in range(count):
                f = i / (count - 1); waves[-count + i] = waves[-count + i] * (1 - f) + piece[i] * f
            waves.extend(piece[count:])
        else:
            waves.extend(piece)
    rows = [encode(periodic(waves), output / 'ocean_waves.ogg')]
    birds = array('f', [0.0]) * (48 * RATE)
    for number, second in enumerate([5, 22, 37], start=1):
        piece = normalize(decode(source / f'gull{number}.wav'), .40)
        for i, value in enumerate(piece):
            fade = min(1., i / (RATE * .03), (len(piece) - i - 1) / (RATE * .06))
            index = second * RATE + i
            if index < len(birds): birds[index] += value * max(0., fade)
    rows.append(encode(birds, output / 'seagulls.ogg'))
    with zipfile.ZipFile(source / 'stream.zip') as archive:
        original = archive.read('stream-waterfall/stream1.ogg')
    stream = source / 'stream1.ogg'; stream.write_bytes(original)
    rows.append(encode(periodic(normalize(decode(stream), .32)), output / 'creek.ogg'))
    metadata = dict(prepared='2026-11-04', processing='mono 32 kHz; DC removal, conservative peak leveling, edge crossfade; gull calls spaced across a 48-second loop',
                    files=rows, downloads=json.loads((source / 'downloads.json').read_text()),
                    stream_original_sha256=hashlib.sha256(original).hexdigest())
    (output / 'preparation.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
