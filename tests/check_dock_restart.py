import os, subprocess, sys, tempfile
from pathlib import Path
import yaml
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dock-failure-') as directory:
    marker = str(Path(directory) / 'restarted')
    play = [{
        'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
        'vars_files': [str(repo/'vars/macbook.yml')],
        'vars': {'role_path': str(repo / 'roles/macbook_dock'), 'dockitems_persist': "{{ dockitems_persist_layout | selectattr('profile', 'in', ['all', 'personal']) | list }}"},
        'tasks': [
            {'name': 'Queue the Dock restart', 'ansible.builtin.debug': {'msg': 'queued'}, 'changed_when': True, 'notify': 'Restart Dock'},
            {'name': 'Run actual Dock tasks', 'ansible.builtin.import_tasks': str(repo/'roles/macbook_dock/tasks/main.yml')},
            {'name': 'Simulate later installer failure', 'ansible.builtin.fail': {'msg': 'expected later failure'}}],
        'handlers': [{'name': 'Restart Dock', 'ansible.builtin.copy': {'content': 'restarted', 'dest': marker, 'mode': '0600'}}]
    }]
    path = Path(directory)/'play.yml'
    path.write_text(yaml.safe_dump(play))
    result = subprocess.run([sys.executable, '-m', 'ansible.cli.playbook', '-i', 'localhost,', str(path)], env=dict(os.environ, ANSIBLE_LOCAL_TEMP=directory), text=True, capture_output=True)
    assert 'expected later failure' in result.stdout, result.stdout + result.stderr
    assert Path(marker).exists(), 'FAIL: later task failure prevented the Dock restart'
    print('PASS: Dock restart completed before the later failure')
