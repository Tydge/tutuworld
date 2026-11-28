import http.client
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('auth_service', Path(__file__).resolve().parents[1] / 'server/auth_service.py')
auth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auth)


class AccountRules(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='tutu-auth-test-')
        auth.STATE = Path(self.folder.name)

    def tearDown(self):
        self.folder.cleanup()

    def register(self):
        return auth.handle('register', {'username': 'Island_User', 'password': 'a-private-test-password'})

    def test_register_login_and_password_storage(self):
        result = self.register()
        self.assertTrue(result['ok'])
        self.assertFalse(auth.handle('register', {'username': 'island_user', 'password': 'another-password'})['ok'])
        with auth.database() as db:
            row = db.execute('SELECT salt,digest FROM accounts').fetchone()
            self.assertEqual(len(row[0]), 16)
            self.assertEqual(len(row[1]), 64)
            self.assertNotIn(b'a-private-test-password', row[1])
        self.assertFalse(auth.handle('login', {'username': 'island_user', 'password': 'wrong-password'})['ok'])
        logged_in = auth.handle('login', {'username': 'ISLAND_USER', 'password': 'a-private-test-password'})
        self.assertTrue(logged_in['ok'])
        self.assertEqual(logged_in['account_id'], result['account_id'])

    def test_sessions_and_expiry(self):
        result = self.register()
        self.assertTrue(auth.handle('resume', {'token': result['token']})['ok'])
        self.assertFalse(auth.handle('resume', {'token': 'forged-token'})['ok'])
        auth.handle('logout', {'token': result['token']})
        self.assertFalse(auth.handle('resume', {'token': result['token']})['ok'])

    def test_input_and_attempt_limits(self):
        self.assertFalse(auth.handle('register', {'username': 'a', 'password': 'long-enough-password'})['ok'])
        self.assertFalse(auth.handle('register', {'username': 'valid-user', 'password': '123'})['ok'])
        self.register()
        for _ in range(8):
            self.assertFalse(auth.handle('login', {'username': 'island_user', 'password': 'wrong-password'})['ok'])
        self.assertFalse(auth.handle('login', {'username': 'island_user', 'password': 'a-private-test-password'})['ok'])


class DownloadRules(unittest.TestCase):
    def test_platforms_and_manifest_promotion(self):
        with tempfile.TemporaryDirectory() as folder:
            release = Path(folder) / 'manifest.json'
            with patch.dict(os.environ, TUTU_RELEASE_MANIFEST=str(release)), auth.ThreadingHTTPServer(('127.0.0.1', 0), auth.Handler) as server:
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    for version in ['1.2.3', '1.2.4']:
                        release.write_text(json.dumps({'payload': json.dumps({'version': version})}))
                        for ua, name in [('Windows NT 10.0', 'Windows'), ('Macintosh', 'macOS')]:
                            connection = http.client.HTTPConnection(*server.server_address)
                            connection.request('HEAD', '/tutuworld/download', headers={'User-Agent': ua})
                            response = connection.getresponse()
                            self.assertEqual(response.status, 302)
                            self.assertEqual(response.getheader('Location'), f'/tutuworld/releases/{version}/TutuWorld-{name}.zip')
                            self.assertEqual(response.getheader('Cache-Control'), 'no-store')
                            self.assertEqual(response.read(), b'')
                            connection.close()
                    connection = http.client.HTTPConnection(*server.server_address)
                    connection.request('GET', '/tutuworld/download/', headers={'User-Agent': 'iPhone like Mac OS X'})
                    page = connection.getresponse().read().decode()
                    self.assertIn('?platform=macos', page)
                    self.assertIn('?platform=windows', page)
                    connection.close()
                    release.write_text('{}')
                    connection = http.client.HTTPConnection(*server.server_address)
                    connection.request('GET', '/tutuworld/download?platform=windows')
                    self.assertEqual(connection.getresponse().status, 503)
                    connection.close()
                finally:
                    server.shutdown()
                    thread.join()


if __name__ == '__main__':
    unittest.main()
