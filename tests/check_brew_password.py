import os, secrets, subprocess, sys, tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
password = secrets.token_urlsafe()
with tempfile.TemporaryDirectory(prefix='brew-bridge-') as directory:
    play = Path(directory) / 'play.yml'
    play.write_text('''- hosts: localhost
  gather_facts: false
  tasks:
    - name: Bridge prompted password
      macbook_brew_password:
      register: credentials
      no_log: true
    - name: Keep the credential outside fact caches
      ansible.builtin.set_fact:
        ansible_become_password: "{{ credentials.password }}"
        cacheable: false
      no_log: true
    - name: Verify credential is available only as an ephemeral variable
      ansible.builtin.assert:
        that:
          - ansible_become_password == lookup('env', 'BRIDGE_EXPECTED')
          - "'ansible_become_password' not in ansible_facts"
      no_log: true
''')
    env = dict(os.environ, ANSIBLE_LOCAL_TEMP=directory, ANSIBLE_ACTION_PLUGINS=str(repo / 'action_plugins'), BRIDGE_EXPECTED=password)
    result = subprocess.run([sys.executable, '-m', 'ansible.cli.playbook', '-i', 'localhost,', str(play), '-K'], input=password+'\n', text=True, capture_output=True, env=env)
    assert password not in result.stdout
    assert result.returncode == 0, (result.stdout + result.stderr).replace(password, '[REDACTED]')
    print('Real -K integration passed: credential available, uncached, hidden from output.')
