import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('set_dock', Path(__file__).resolve().parents[1] / 'files/macbook/set-dock.py')
dock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dock)


class DockTest(unittest.TestCase):
    def test_native_tiles_replace_path_only_tiles_and_preserve_preferences(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Example.app'
            app.mkdir()
            apps = [{'name': 'Example', 'path': str(app)}]
            current = {'orientation': 'right', 'persistent-apps': [dock.tile(app, 'Example')]}
            current['persistent-apps'][0]['tile-data']['file-data']['_CFURLStringType'] = 0
            with patch.object(dock.subprocess, 'check_output', return_value=plistlib.dumps(current)), patch.object(dock.subprocess, 'run') as write:
                self.assertEqual(dock.configure(apps), 'updated')
                updated = plistlib.loads(write.call_args.kwargs['input'])
            self.assertEqual(updated['orientation'], 'right')
            data = updated['persistent-apps'][0]['tile-data']['file-data']
            self.assertEqual(data, {'_CFURLString': app.as_uri(), '_CFURLStringType': 15})
            downloads = updated['persistent-others'][0]['tile-data']
            self.assertEqual((downloads['showas'], downloads['displayas'], downloads['arrangement']), (2, 1, 2))
            updated['persistent-apps'][0]['tile-data']['book'] = b'native bookmark'
            with patch.object(dock.subprocess, 'check_output', return_value=plistlib.dumps(updated)), patch.object(dock.subprocess, 'run') as write:
                self.assertEqual(dock.configure(apps), 'unchanged')
                write.assert_not_called()

    def test_missing_application_does_not_clear_pins(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(dock.subprocess, 'run') as write:
            with self.assertRaises(FileNotFoundError):
                dock.configure([{'name': 'Missing', 'path': str(Path(directory) / 'Missing.app')}])
            write.assert_not_called()


if __name__ == '__main__':
    unittest.main()
