"""install.ps1 only reports WSL as ready when nvim 0.11+, tmux and cv are all there.

The check is a bash one-liner inside install.ps1; this runs it against fake machines.
Run: python3 -m pytest tests
"""
import os
import pathlib
import re
import subprocess

INSTALL_PS1 = pathlib.Path(__file__).resolve().parent.parent / "install.ps1"


def ready_check():
    """The bash the installer sends to WSL, with PowerShell's '' quoting undone."""
    m = re.search(r"\$check = '(.*?)' \+\s*'(.*?)'\n", INSTALL_PS1.read_text(), re.S)
    return (m.group(1) + m.group(2)).replace("''", "'")


def machine(tmp_path, nvim_version=None, tmux=True, cv=True):
    bin_dir, home = tmp_path / "bin", tmp_path / "home"
    (home / ".dotfiles" / "bin").mkdir(parents=True)
    bin_dir.mkdir()
    for tool in ("head", "sort", "printf"):
        (bin_dir / tool).symlink_to(subprocess.check_output(["bash", "-c", f"command -v {tool}"], text=True).strip())
    if nvim_version:
        (bin_dir / "nvim").write_text(f"#!/bin/sh\necho 'NVIM v{nvim_version}'\n")
        (bin_dir / "nvim").chmod(0o755)
    if tmux:
        (bin_dir / "tmux").write_text("#!/bin/sh\n")
        (bin_dir / "tmux").chmod(0o755)
    if cv:
        (home / ".dotfiles" / "bin" / "cv").write_text("#!/bin/sh\n")
        (home / ".dotfiles" / "bin" / "cv").chmod(0o755)
    return {"PATH": str(bin_dir), "HOME": str(home)}


def report(env):
    return subprocess.run(["/bin/bash", "-c", ready_check()], env=env, capture_output=True, text=True).stdout.strip()


def test_a_set_up_machine_is_ready_and_says_which_nvim(tmp_path):
    assert report(machine(tmp_path, nvim_version="0.11.7")) == "ok nvim 0.11.7"


def test_a_machine_without_nvim_is_not_ready(tmp_path):
    assert report(machine(tmp_path, nvim_version=None)) == ""


def test_a_machine_with_an_old_nvim_is_not_ready(tmp_path):
    assert report(machine(tmp_path, nvim_version="0.9.5")) == ""


def test_a_machine_without_tmux_is_not_ready(tmp_path):
    assert report(machine(tmp_path, nvim_version="0.11.7", tmux=False)) == ""


def test_a_machine_without_the_dotfiles_is_not_ready(tmp_path):
    assert report(machine(tmp_path, nvim_version="0.11.7", cv=False)) == ""
