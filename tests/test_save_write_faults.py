"""Run a real short-write fault in one isolated Godot child, never player data."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.dev import godot_path


@unittest.skipUnless(os.name == 'posix', 'RLIMIT_FSIZE requires POSIX')
class SaveWriteFaults(unittest.TestCase):
    def test_short_write_preserves_primary_backup_and_building_checkpoint(self):
        import resource
        try:
            binary = godot_path()
        except SystemExit:
            self.skipTest('Godot is unavailable')
        (ROOT / '.qa-artifacts').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='save-fault-', dir=ROOT / '.qa-artifacts') as fixture:
            fixture = Path(fixture)
            base = [binary, '--headless', '--path', str(ROOT), '--script',
                    'res://tests/save_write_fault_probe.gd', '--log-file', str(fixture / 'engine.log'),
                    '--', '--test', '--fixture-root', str(fixture)]
            setup = subprocess.run(base, capture_output=True, text=True, timeout=30)
            self.assertEqual(setup.returncode, 0, setup.stdout + setup.stderr)
            self.assertIn('SAVE_FAULT_SETUP true', setup.stdout)
            baseline = json.loads((fixture / 'save.json').read_text())
            self.assertEqual(baseline['schema'], 3)

            def constrain_child():
                signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
                resource.setrlimit(resource.RLIMIT_FSIZE, (1024, 1024))

            child = subprocess.run(base + ['--limited-write'], preexec_fn=constrain_child,
                                   capture_output=True, text=True, timeout=30)
            self.assertEqual(child.returncode, 0, child.stdout + child.stderr)
            line = next(row for row in child.stdout.splitlines() if row.startswith('SAVE_FAULT_PROBE '))
            result = json.loads(line.removeprefix('SAVE_FAULT_PROBE '))
            self.assertFalse(result['save_returned'], result)
            self.assertFalse(result['backup_returned'], result)
            for field in ('primary_preserved', 'backup_preserved', 'checkpoint_preserved'):
                self.assertTrue(result[field], result)
            json.loads((fixture / 'save.json').read_text())
            json.loads((fixture / 'save.json.bak').read_text())


if __name__ == '__main__':
    unittest.main()
