#!/usr/bin/env python3
"""Run an isolated local world and two Godot clients; never use production data."""
import argparse
import datetime as dt
import os
from pathlib import Path
import socket
import subprocess
import time

from dev import godot_path

ROOT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        return listener.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot')
    parser.add_argument('--check', action='store_true', help='Check both clients headlessly, then exit')
    args = parser.parse_args()
    binary = godot_path(args.godot)
    output = ROOT / '.qa-artifacts' / ('local-multiplayer-' + dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    output.mkdir(parents=True)
    auth_port, game_port = free_port(), free_port()
    while game_port == auth_port:
        game_port = free_port()
    env = os.environ.copy()
    env.update(TUTU_AUTH_PORT=str(auth_port), TUTU_GAME_PORT=str(game_port),
               TUTU_STATE_DIR=str(output / 'state'), TUTU_TEST_ENDPOINT=f'ws://127.0.0.1:{game_port}')
    env.pop('TUTU_RELEASE_MANIFEST', None)
    processes, logs = [], []

    def start(name, command):
        log = (output / (name + '.log')).open('w', encoding='utf-8')
        logs.append(log)
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append(process)
        return process

    def wait_ready(process, name, ready):
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            text = (output / (name + '.log')).read_text(encoding='utf-8', errors='replace')
            if ready in text:
                return
            if process.poll() is not None or 'SCRIPT ERROR' in text:
                raise RuntimeError(f'{name} 启动失败，请查看 {output / (name + ".log")}')
            time.sleep(.2)
        raise RuntimeError(f'{name} 启动超时，请查看 {output / (name + ".log")}')

    try:
        import sys
        auth = start('auth', [sys.executable, '-u', str(ROOT / 'server/auth_service.py')])
        deadline = time.monotonic() + 10
        while True:
            try:
                with socket.create_connection(('127.0.0.1', auth_port), timeout=.2):
                    break
            except OSError:
                if auth.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError(f'本地账号服务未就绪，请查看 {output / "auth.log"}')
                time.sleep(.1)
        server = start('world', [binary, '--headless', '--path', str(ROOT), '--script', 'res://server/main.gd'])
        wait_ready(server, 'world', 'TUTU_SERVER_READY')
        clients = []
        for role in ['builder', 'visitor']:
            flags = ['--headless'] if args.check else ['--windowed']
            command = [binary, '--path', str(ROOT), *flags, '--script', 'res://tools/local_multiplayer_preview.gd',
                       '--', '--test', '--benchmark', '--' + role]
            if args.check:
                command.append('--preview-check')
            clients.append(start(role, command))
        print('本地双人世界已启动。两个窗口分别操作兔兔和猫咪；可各自到东岸购地并建造。', flush=True)
        print('使用全新隔离账号和世界；关闭两个游戏窗口或在此按 Ctrl+C 即可结束。', flush=True)
        print('测试记录：', output, flush=True)
        for process, role in zip(clients, ['builder', 'visitor']):
            wait_ready(process, role, 'LOCAL_MULTIPLAYER_PREVIEW_READY')
        while any(process.poll() is None for process in clients):
            if server.poll() is not None or auth.poll() is not None:
                raise RuntimeError(f'本地服务意外退出，请查看 {output}')
            time.sleep(.25)
        if any(process.returncode != 0 for process in clients):
            raise RuntimeError(f'测试窗口异常退出，请查看 {output}')
        print('本地双人检查通过。' if args.check else '本地测试已结束。')
        return 0
    except KeyboardInterrupt:
        return 0
    except RuntimeError as error:
        print(error)
        return 1
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
        for process in reversed(processes):
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for log in logs:
            log.close()


if __name__ == '__main__':
    raise SystemExit(main())
