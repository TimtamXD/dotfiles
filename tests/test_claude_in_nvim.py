"""Claude Code inside Neovim (claudecode.nvim): ask about the codebase, send a selection,
accept or reject its edits as diffs. Uses the Claude Code CLI and its sign-in, no API key.

Run: python3 -m pytest tests
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
AI = ROOT / "nvim" / "lua" / "plugins" / "ai.lua"


def keymap(lhs):
    return re.search(r'\{\s*"' + re.escape(lhs) + r'",\s*"([^"]+)"', AI.read_text())


def test_the_claude_plugin_is_loaded_with_the_other_plugins():
    assert '{ import = "plugins.ai" }' in (ROOT / "nvim" / "lua" / "config" / "plugins.lua").read_text()
    assert "coder/claudecode.nvim" in AI.read_text()


def test_leader_a_c_opens_claude_to_ask_it_anything_about_the_project():
    assert keymap("<leader>ac").group(1) == "<cmd>ClaudeCode<cr>"


def test_a_selection_can_be_sent_and_the_current_file_added():
    assert keymap("<leader>as").group(1) == "<cmd>ClaudeCodeSend<cr>"
    assert keymap("<leader>ab").group(1) == "<cmd>ClaudeCodeAdd %<cr>"


def test_claudes_edits_are_accepted_or_rejected_as_diffs():
    assert keymap("<leader>aa").group(1) == "<cmd>ClaudeCodeDiffAccept<cr>"
    assert keymap("<leader>ad").group(1) == "<cmd>ClaudeCodeDiffDeny<cr>"


def test_it_needs_no_extra_terminal_plugin():
    assert 'provider = "native"' in AI.read_text()


def test_the_installer_puts_claude_code_on_machines_without_it():
    assert "https://claude.ai/install.sh" in (ROOT / "install.sh").read_text()
