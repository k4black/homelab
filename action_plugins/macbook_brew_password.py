"""Expose Ansible's prompted become password to Homebrew's askpass helper."""

from ansible.plugins.action import ActionBase


class ActionModule(ActionBase):
    _requires_connection = False

    def run(self, tmp=None, task_vars=None):
        result = super().run(tmp, task_vars)
        result.update(changed=False, _ansible_no_log=True)
        variables = task_vars or {}
        # Explicit inventory/vault/extra vars take precedence over the CLI prompt.
        password = variables.get(
            "ansible_become_password",
            variables.get("ansible_become_pass", self._play_context.become_pass),
        )
        if password:
            result["password"] = password
        return result
