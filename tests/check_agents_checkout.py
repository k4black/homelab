"""Check fresh, clean, and locally modified agent checkouts without network access."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import yaml

repo = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)


with tempfile.TemporaryDirectory(prefix='agents-checkout-') as directory:
    root = Path(directory)
    source = root / 'source'
    source.mkdir()
    run('git', 'init', '-b', 'main', str(source))
    installer = source / 'install.sh'
    installer.write_text('# fixture revision one\n')

    def commit():
        run('git', '-C', str(source), 'add', 'install.sh')
        run('git', '-C', str(source), '-c', 'commit.gpgsign=false', '-c', 'user.name=CI', '-c', 'user.email=ci@invalid',
            'commit', '-m', 'test: update fixture')

    commit()
    destination = root / 'checkout'
    play = root / 'play.yml'
    play.write_text(yaml.safe_dump([{
        'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
        'vars': {'testing': 'true', 'agents_setup_repo': str(source),
                 'agents_setup_dest': str(destination), 'agents_setup_version': 'main',
                 'agents_setup_brew_casks': [], 'agents_setup_brew_formulae': [],
                 'bitwarden_ssh_agent_sock': str(root / 'unused-agent')},
        'tasks': [{'ansible.builtin.import_tasks': str(repo / 'roles/agents_setup/tasks/checkout.yml')}]
    }]))

    def provision():
        result = subprocess.run([sys.executable, '-m', 'ansible.cli.playbook', '-i',
                                 'localhost,', str(play)], capture_output=True, text=True,
                                env=dict(os.environ, ANSIBLE_LOCAL_TEMP=directory))
        assert result.returncode == 0, result.stdout + result.stderr

    provision()
    assert (destination / 'install.sh').read_text() == installer.read_text()
    installer.write_text('# fixture revision two\n')
    commit()
    provision()
    assert (destination / 'install.sh').read_text() == installer.read_text()
    local = destination / 'install.sh'
    local.write_text('# local edits must survive\n')
    untracked = destination / 'local.txt'
    untracked.write_text('local content\n')
    provision()
    assert local.read_text() == '# local edits must survive\n'
    assert untracked.read_text() == 'local content\n'
    print('PASS: fresh clone, clean update, and preserved local edits')
