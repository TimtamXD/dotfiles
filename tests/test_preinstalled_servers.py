"""The installers put the everyday language servers in place up front, so the first file of
each kind opens with code navigation already working.

Run: python3 -m pytest tests
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGES = [l.split("#")[0].strip() for l in (ROOT / "nvim" / "mason-packages.txt").read_text().splitlines()]
PACKAGES = [p for p in PACKAGES if p]


def test_rust_python_and_javascript_servers_are_preinstalled():
    assert {"rust-analyzer", "basedpyright", "ruff", "typescript-language-server"} <= set(PACKAGES)


def test_web_and_config_file_servers_are_preinstalled():
    assert {"eslint-lsp", "html-lsp", "css-lsp", "tailwindcss-language-server", "json-lsp",
            "yaml-language-server", "taplo", "marksman", "bash-language-server", "lua-language-server"} <= set(PACKAGES)


def test_each_package_is_listed_once():
    assert len(PACKAGES) == len(set(PACKAGES))


def test_the_linux_and_mac_installer_preinstalls_the_list():
    assert "nvim/mason-packages.txt" in (ROOT / "install.sh").read_text()


def test_the_windows_installer_preinstalls_the_list():
    assert "nvim/mason-packages.txt" in (ROOT / "install.ps1").read_text()


def test_ubuntu_gets_python_venv_which_mason_needs_for_python_servers():
    assert "python3-venv" in (ROOT / "install.sh").read_text()
