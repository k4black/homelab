"""Regression coverage for the -K / Homebrew password bridge."""

import secrets
import unittest
from unittest.mock import patch

from ansible.playbook.play_context import PlayContext
from ansible.plugins.action import ActionBase

from action_plugins.macbook_brew_password import ActionModule


class BrewPasswordTest(unittest.TestCase):
    def run_action(self, prompted=None, variables=None):
        action = object.__new__(ActionModule)
        action._play_context = PlayContext(passwords={"become_pass": prompted})
        with patch.object(ActionBase, "run", return_value={}):
            return action.run(task_vars=variables)

    def test_prompt_is_forwarded_without_logging_or_caching(self):
        password = secrets.token_urlsafe()
        result = self.run_action(prompted=password)
        self.assertEqual(result["password"], password)
        self.assertTrue(result["_ansible_no_log"])
        self.assertNotIn("ansible_facts", result)
        self.assertFalse(result["changed"])

    def test_explicit_variables_override_prompt(self):
        for name in ("ansible_become_password", "ansible_become_pass"):
            with self.subTest(name=name):
                password = secrets.token_urlsafe()
                result = self.run_action(secrets.token_urlsafe(), {name: password})
                self.assertEqual(result["password"], password)

    def test_passwordless_sudo_needs_no_fact(self):
        result = self.run_action()
        self.assertNotIn("password", result)
        self.assertNotIn("ansible_facts", result)


if __name__ == "__main__":
    unittest.main()
