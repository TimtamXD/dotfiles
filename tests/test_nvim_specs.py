"""Runs the Neovim Lua specs (tests/*_spec.lua) with `nvim -l`, where nvim is installed."""
import pathlib
import shutil
import subprocess

import pytest

SPECS = sorted(pathlib.Path(__file__).resolve().parent.glob("*_spec.lua"))


@pytest.mark.skipif(shutil.which("nvim") is None, reason="nvim is not installed here")
@pytest.mark.parametrize("spec", SPECS, ids=[s.stem for s in SPECS])
def test_lua_spec_passes(spec):
    r = subprocess.run(["nvim", "--clean", "-l", str(spec)], capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stdout + r.stderr
