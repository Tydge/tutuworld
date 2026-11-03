#!/usr/bin/env python3
"""Local development entry point. No package installation, exports or uploads."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = json.loads((ROOT / 'tools/test_suites.json').read_text(encoding='utf-8'))


def godot_path(override=None):
    candidates = [override, os.environ.get('GODOT_BIN'), shutil.which('godot'),
                  str(Path.home() / 'Desktop/Godot.app/Contents/MacOS/Godot'),
                  '/Applications/Godot.app/Contents/MacOS/Godot']
    for value in candidates:
        if value and Path(value).is_file():
            return str(Path(value).resolve())
    raise SystemExit('Godot not found. Set GODOT_BIN or pass --godot before the command.')


def doctor(binary):
    version = subprocess.check_output([binary, '--version'], text=True, timeout=15).strip()
    print('Godot:', version, '\nProject:', ROOT)
    missing = []
    for folder in ['scripts', 'tests', 'scenes', 'config', 'assets/shaders']:
        for path in (ROOT / folder).rglob('*'):
            if not path.is_file() or path.suffix not in {'.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc'}:
                continue
            text = path.read_text(encoding="utf-8")
            for resource in re.findall(r'"res://([^"\n]*)"(?!\s*\+)' , text):
                if '*' not in resource and not resource.startswith('.qa-artifacts/') and not (ROOT / resource).exists():
                    missing.append(f'{path.relative_to(ROOT)}: res://{resource}')
    if missing:
        raise SystemExit('Missing literal resources:\n' + '\n'.join(missing))
    print('Literal resource paths: OK. Run the smoke suite for Godot script/dependency checks.')
    return 0


def guarded(binary, name, arguments, output, timeout):
    folder = output / name
    folder.mkdir(parents=True, exist_ok=True)
    log = folder / 'run.log'
    env = os.environ.copy()
    env['TUTU_QA_OUTPUT'] = str(folder / 'screenshots')
    start = time.monotonic()
    reason = ''
    with log.open('w', encoding='utf-8') as handle:
        process = subprocess.Popen([binary, '--path', str(ROOT)] + arguments,
                                   cwd=ROOT, env=env, stdout=handle, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                content = log.read_text(encoding='utf-8', errors='replace')
                if time.monotonic() - start > timeout:
                    reason = 'timeout'
                elif 'SCRIPT ERROR' in content or 'SHADER ERROR' in content:
                    reason = 'script/shader error'
                if reason:
                    process.terminate()
                    try:
                        process.wait(timeout=4)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    break
                time.sleep(.2)
        except KeyboardInterrupt:
            process.terminate()
            try:
                process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise
    content = log.read_text(encoding='utf-8', errors='replace')
    failed = (process.returncode != 0 or reason or 'SCRIPT ERROR' in content or 'SHADER ERROR' in content
              or re.search(r'^FAIL\b|_RESULT FAIL', content, re.M))
    print(f'[{"FAIL" if failed else "PASS"}] {name} ({time.monotonic()-start:.1f}s) {reason}')
    print('\n'.join(content.splitlines()[-10:]))
    print('Log:', log)
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', help='Godot executable (or set GODOT_BIN)')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('doctor')
    commands.add_parser('run')
    test = commands.add_parser('test')
    test.add_argument('names', nargs='*', help='tests/<name>.gd, or a named entry in test_suites.json')
    test.add_argument('--suite', choices=SUITES['suites'], help='Run sequentially; default smoke')
    test.add_argument('--timeout', type=int, default=180)
    test.add_argument('--windowed', action='store_true', help='Run graphical checks windowed and on top (useful on macOS)')
    test.add_argument('--allow-network', action='store_true', help='Required for the live update download test')
    test.add_argument('--game-arg', action='append', default=[])
    build = commands.add_parser('build')
    build.add_argument('map', choices=['city', 'valley'])
    build.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    binary = godot_path(args.godot)
    if args.command == 'doctor':
        return doctor(binary)
    if args.command == 'run':
        return subprocess.call([binary, '--path', str(ROOT)], cwd=ROOT)
    output = ROOT / '.qa-artifacts' / dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    if args.command == 'build':
        script = f'res://scripts/{args.map}/build_{args.map}.gd'
        return guarded(binary, 'build_' + args.map,
                       ['--rendering-method', 'gl_compatibility', '--max-fps', '30', '--script', script],
                       output, args.timeout)
    if args.names and args.suite:
        parser.error('Choose explicit test names or --suite, not both.')
    names = args.names or SUITES['suites'][args.suite or 'smoke']
    for name in names:
        name = name.removesuffix('.gd')
        entry = SUITES['tests'].get(name, {})
        script = entry.get('script', name)
        if not re.fullmatch(r'[a-zA-Z0-9_]+', script) or not (ROOT / 'tests' / (script + '.gd')).is_file():
            parser.error('Unknown test: ' + name)
        if script == 'test_support':
            parser.error('test_support is a helper, not a test.')
        if script == 'update_download' and not args.allow_network:
            parser.error('update_download contacts the live update server; add --allow-network explicitly.')
        if script == 'update_integrity' and '--fixture' not in args.game_arg:
            parser.error('update_integrity requires --game-arg=--fixture --game-arg=/path/to/signed/manifest.json')
        flags = ['--headless'] if entry.get('headless', False) else []
        if args.windowed and not entry.get('headless', False):
            flags += ['--windowed', '--always-on-top']
        flags += ['--script', f'res://tests/{script}.gd', '--', '--test']
        flags += entry.get('args', []) + args.game_arg
        if guarded(binary, name, flags, output, args.timeout):
            return 1
    print('All selected checks passed. Evidence:', output)
    return 0


if __name__ == '__main__':
    sys.exit(main())
