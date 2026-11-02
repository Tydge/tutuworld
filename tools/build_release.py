"""Build reviewed desktop packages and content. Output stays outside source control."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--d3d12-sdk', type=Path, help='Official Microsoft.Direct3D.D3D12 1.618.5 NuGet package')
    parser.add_argument('--part', choices=['all', 'macos', 'windows', 'content', 'server'], default='all')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = re.search(r'const VERSION := "([^"]+)"', (ROOT / 'scripts/services/release.gd').read_text()).group(1)

    def export(part, preset, destination, pack=False):
        destination.parent.mkdir(parents=True, exist_ok=True)
        log = output / (part + '-export.log')
        command = [str(args.godot), '--headless', '--path', str(ROOT), '--export-pack' if pack else '--export-release', preset, str(destination)]
        with log.open('w') as handle:
            result = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT)
        text = log.read_text()
        if result.returncode or 'SCRIPT ERROR' in text or 'SHADER ERROR' in text or not destination.exists():
            raise SystemExit(f'{part} export failed. See {log}\n' + '\n'.join(text.splitlines()[-15:]))
        print(f'{part}: OK ({destination.stat().st_size:,} bytes) log={log}', flush=True)

    if args.part in ['all', 'macos']:
        export('macos', 'macOS', output / 'TutuWorld-macOS.zip')
    if args.part in ['all', 'windows']:
        windows = output / 'windows'
        export('windows', 'Windows', windows / 'TutuWorld.exe')
        if args.d3d12_sdk:
            with zipfile.ZipFile(args.d3d12_sdk) as sdk:
                runtime=windows/'x86_64';runtime.mkdir(exist_ok=True)
                (runtime/'D3D12Core.dll').write_bytes(sdk.read('build/native/bin/x64/D3D12Core.dll'))
                for license_name in ['LICENSE.txt','LICENSE-CODE.txt']:
                    (runtime/license_name).write_bytes(sdk.read(license_name))
        else:
            raise SystemExit('Windows release requires --d3d12-sdk from Microsoft official NuGet 1.618.5')
        (windows / '使用说明.txt').write_text('兔兔的世界 ' + version + '\n\n请解压整个文件夹，再打开 TutuWorld.exe。\n默认全屏、60 FPS上限、均衡画质；显卡默认优先独立显卡。\n多人游戏需连接网络并更新到最新版本。\n', encoding='utf-8-sig')
        with zipfile.ZipFile(output / 'TutuWorld-Windows.zip', 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for file in sorted(windows.rglob('*')):
                if file.is_file():
                    archive.write(file, 'TutuWorld-' + version + '/' + file.relative_to(windows).as_posix())
        print('windows archive: OK', flush=True)
    if args.part in ['all', 'content']:
        export('content', 'Windows', output / 'city.pck', True)
    if args.part in ['all', 'server']:
        export('server', 'Server', output / 'server.pck', True)


if __name__ == '__main__':
    main()
