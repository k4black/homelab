"""Set native Dock tiles without a partially cleared intermediate layout."""
import json
from pathlib import Path
import plistlib
import subprocess
import sys


def tile(path, label, **options):
    return {
        'tile-type': 'directory-tile' if options else 'file-tile',
        'tile-data': {
            'file-data': {'_CFURLString': Path(path).expanduser().as_uri(), '_CFURLStringType': 15},
            'file-label': label,
            **options,
        },
    }


def matches(current, wanted):
    if len(current) != len(wanted):
        return False
    for existing, desired in zip(current, wanted):
        if existing.get('tile-type') != desired['tile-type']:
            return False
        data = existing.get('tile-data', {})
        for key, value in desired['tile-data'].items():
            actual = data.get(key)
            if key == 'file-data' and isinstance(actual, dict):
                if actual.get('_CFURLString', '').rstrip('/') != value['_CFURLString'].rstrip('/'):
                    return False
                if actual.get('_CFURLStringType') != 15:
                    return False
            elif actual != value:
                return False
    return True


def configure(apps, check=False):
    for app in apps:
        if not Path(app['path']).is_dir():
            raise FileNotFoundError(f"Dock application is missing: {app['path']}")
    prefs = plistlib.loads(subprocess.check_output(['defaults', 'export', 'com.apple.dock', '-']))
    desired = {
        'persistent-apps': [tile(app['path'], app['name']) for app in apps],
        'persistent-others': [tile(Path.home() / 'Downloads', 'Downloads', showas=2, displayas=1, arrangement=2)],
    }
    if all(matches(prefs.get(key, []), value) for key, value in desired.items()):
        return 'unchanged'
    if check:
        return 'would change'
    prefs.update(desired)
    subprocess.run(['defaults', 'import', 'com.apple.dock', '-'], input=plistlib.dumps(prefs), check=True, capture_output=True)
    return 'updated'


if __name__ == '__main__':
    print(configure(json.loads(sys.argv[1]), check='--check' in sys.argv[2:]))
