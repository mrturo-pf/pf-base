#!/usr/bin/env python3
"""Focused safety tests for ecosystem-git planning decisions."""
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("ecosystem_git", Path(__file__).with_name("ecosystem-git.py"))
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules["ecosystem_git"] = MODULE
SPEC.loader.exec_module(MODULE)


class PlanningSafetyTests(unittest.TestCase):
    def state(self) -> MODULE.RepoState:
        return MODULE.RepoState("pf-rates", "modules/pf-rates", "main", "main", False)

    @patch.object(MODULE, "dependent_prs", return_value=[])
    @patch.object(MODULE, "remote_sha", return_value="abc")
    @patch.object(MODULE, "prs")
    @patch.object(MODULE, "git", return_value="abc")
    def test_merged_pr_with_matching_sha_is_cleanup(self, git, prs, remote, dependents):
        prs.return_value = [{"state": "MERGED", "baseRefName": "main", "number": 1, "headRefOid": "abc"}]
        state = self.state()
        MODULE.inspect_branch(state, Path("."), "mrturo-pf/pf-rates", "feature/x", True)
        self.assertEqual(state.actions[0].kind, "CLEANUP")

    @patch.object(MODULE, "prs", return_value=[{"state": "MERGED", "baseRefName": "main", "number": 1, "headRefOid": "old"}])
    @patch.object(MODULE, "remote_sha", return_value="new")
    @patch.object(MODULE, "git", return_value="new")
    def test_merged_pr_with_newer_head_is_blocked(self, git, remote, prs):
        state = self.state()
        MODULE.inspect_branch(state, Path("."), "mrturo-pf/pf-rates", "feature/x", True)
        self.assertEqual(state.actions[0].kind, "BLOCK")

    @patch.object(MODULE, "prs", return_value=[{"state": "CLOSED", "baseRefName": "main", "number": 2}])
    @patch.object(MODULE, "remote_sha", return_value="sha")
    @patch.object(MODULE, "git", return_value="sha")
    def test_closed_unmerged_pr_is_not_replaced_automatically(self, git, remote, prs):
        state = self.state()
        MODULE.inspect_branch(state, Path("."), "mrturo-pf/pf-rates", "feature/x", True)
        self.assertEqual(state.actions[0].kind, "BLOCK")

    @patch.object(MODULE, "prs", return_value=[
        {"state": "MERGED", "baseRefName": "main", "number": 1, "headRefOid": "old"},
        {"state": "OPEN", "baseRefName": "main", "number": 3, "url": "url"},
    ])
    @patch.object(MODULE, "remote_sha", return_value="new")
    @patch.object(MODULE, "git", return_value="new")
    def test_open_pr_wins_over_old_merged_pr(self, git, remote, prs):
        state = self.state()
        MODULE.inspect_branch(state, Path("."), "mrturo-pf/pf-rates", "feature/x", True)
        self.assertEqual(state.actions[0].kind, "WAIT")


if __name__ == "__main__":
    unittest.main()
