"""Loopback-only account service. Passwords use scrypt; session tokens are hashed."""
import hashlib
import hmac
import json
import os
import secrets
import socket
import sqlite3
import threading
import time
import unicodedata
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

os.umask(0o077)
STATE = Path(os.environ.get('TUTU_STATE_DIR', '/var/lib/tutuworld'))
LIMIT = threading.BoundedSemaphore(8)


def database():
    STATE.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(STATE / 'accounts.sqlite3', timeout=15)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, salt BLOB NOT NULL, digest BLOB NOT NULL, created REAL NOT NULL)')
    db.execute('CREATE TABLE IF NOT EXISTS sessions (digest TEXT PRIMARY KEY, account TEXT NOT NULL, expires REAL NOT NULL)')
    db.execute('CREATE TABLE IF NOT EXISTS failures (username TEXT PRIMARY KEY, attempts INTEGER NOT NULL, since REAL NOT NULL)')
    return db


def password_hash(password, salt):
    return hashlib.scrypt(password.encode('utf-8'), salt=salt, n=32768, r=8, p=1, maxmem=64 * 1024 * 1024)


def handle(action, data):
    now = time.time()
    with database() as db:
        db.execute('DELETE FROM sessions WHERE expires < ?', (now,))
        if action == 'resume':
            token = str(data.get('token', ''))
            row = db.execute('SELECT account FROM sessions WHERE digest=? AND expires>?', (hashlib.sha256(token.encode()).hexdigest(), now)).fetchone()
            return {'ok': True, 'account_id': row[0], 'token': token} if row else {'ok': False, 'message': '登录已过期，请重新登录。'}
        if action == 'logout':
            db.execute('DELETE FROM sessions WHERE digest=?', (hashlib.sha256(str(data.get('token', '')).encode()).hexdigest(),))
            return {'ok': True}
        username = unicodedata.normalize('NFKC', str(data.get('username', ''))).strip().casefold()
        password = str(data.get('password', ''))
        if not 3 <= len(username) <= 32 or not all(c.isalnum() or c in '._-' for c in username):
            return {'ok': False, 'message': '账号用3～32个文字、字母、数字或下划线。'}
        if not 8 <= len(password.encode('utf-8')) <= 128:
            return {'ok': False, 'message': '密码请使用8～128字节，至少8个英文字母或数字。'}
        row = db.execute('SELECT id,salt,digest FROM accounts WHERE username=?', (username,)).fetchone()
        if action == 'register':
            if row:
                return {'ok': False, 'message': '这个账号已经有人使用啦。'}
            salt = secrets.token_bytes(16)
            account = secrets.token_hex(16)
            try:
                db.execute('INSERT INTO accounts VALUES (?,?,?,?,?)', (account, username, salt, password_hash(password, salt), now))
            except sqlite3.IntegrityError:
                return {'ok': False, 'message': '这个账号已经有人使用啦。'}
        elif action == 'login':
            failure = db.execute('SELECT attempts,since FROM failures WHERE username=?', (username,)).fetchone()
            if failure and failure[0] >= 8 and now - failure[1] < 60:
                return {'ok': False, 'message': '尝试有些频繁，稍等一分钟再来吧。'}
            salt = row[1] if row else bytes(16)
            digest = password_hash(password, salt)
            if not row or not hmac.compare_digest(digest, row[2]):
                attempts = failure[0] + 1 if failure and now - failure[1] < 60 else 1
                since = failure[1] if failure and now - failure[1] < 60 else now
                db.execute('INSERT OR REPLACE INTO failures VALUES (?,?,?)', (username, attempts, since))
                return {'ok': False, 'message': '账号或密码不对，再检查一下吧。'}
            db.execute('DELETE FROM failures WHERE username=?', (username,))
            account = row[0]
        else:
            return {'ok': False, 'message': '请求无效。'}
        token = secrets.token_urlsafe(32)
        db.execute('INSERT INTO sessions VALUES (?,?,?)', (hashlib.sha256(token.encode()).hexdigest(), account, now + 7 * 86400))
        return {'ok': True, 'account_id': account, 'token': token}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path != '/health':
            self.reply(404, {'ok': False})
            return
        ready = False
        try:
            with socket.create_connection(('127.0.0.1', int(os.environ.get('TUTU_GAME_PORT', '18891'))), timeout=.5):
                ready = True
        except OSError:
            pass
        self.reply(200 if ready else 503, {'ok': ready, 'version': os.environ.get('TUTU_VERSION', '0.3.2'), 'build': int(os.environ.get('TUTU_BUILD', '5'))})

    def do_POST(self):
        if not LIMIT.acquire(blocking=False):
            self.reply(429, {'ok': False, 'message': '邮局有点忙，稍后再试。'})
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 4096:
                raise ValueError('size')
            data = json.loads(self.rfile.read(size))
            if not isinstance(data, dict):
                raise ValueError('body')
            self.reply(200, handle(self.path.strip('/'), data))
        except (ValueError, TypeError):
            self.reply(400, {'ok': False, 'message': '请求格式不正确。'})
        except Exception:
            self.reply(503, {'ok': False, 'message': '登录服务暂时忙碌，请稍后再试。'})
        finally:
            LIMIT.release()


if __name__ == '__main__':
    with database() as db:
        db.execute('SELECT 1')
    ThreadingHTTPServer(('127.0.0.1', int(os.environ.get('TUTU_AUTH_PORT', '18892'))), Handler).serve_forever()
