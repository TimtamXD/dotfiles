"""Phone access: from an iPhone, over Tailscale, into WSL's tmux + Neovim.

Opt-in at the PC with:  $env:DOTFILES_PHONE=1; irm .../install.ps1 | iex
Run: python3 -m pytest tests
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
INSTALL_SH = (ROOT / "install.sh").read_text()
INSTALL_PS1 = (ROOT / "install.ps1").read_text()
ZSHRC = (ROOT / "zsh" / "zshrc").read_text()


def function_body(source, name):
    return re.search(rf"^{name}\(\) \{{.*?^\}}", source, re.S | re.M).group(0)


# --- inside WSL (install.sh --phone) ---

def test_phone_access_is_only_set_up_when_asked_for():
    assert re.search(r'--phone\)\s+PHONE=1', INSTALL_SH)
    assert '[[ "$PHONE" == 1 ]] && setup_phone_access' in INSTALL_SH


def test_the_phone_reaches_wsl_through_tailscale_with_its_own_ssh_so_there_are_no_keys():
    body = function_body(INSTALL_SH, "setup_phone_access")
    assert "tailscale.com/install.sh" in body
    assert "--ssh" in body


def test_mosh_is_installed_so_the_session_survives_the_phone_changing_networks():
    assert "mosh" in function_body(INSTALL_SH, "setup_phone_access")


def test_tailscale_needs_systemd_so_wsl_without_it_is_told_how_to_turn_it_on():
    assert "systemd=true" in function_body(INSTALL_SH, "setup_phone_access")


def test_the_phone_command_reopens_the_same_tmux_session_every_time():
    assert re.search(r"phone\(\) \{ tmux new-session -A -s main", ZSHRC)


# --- on Windows (install.ps1 with DOTFILES_PHONE) ---

def test_windows_passes_the_phone_option_to_wsl():
    assert "DOTFILES_PHONE" in INSTALL_PS1
    assert "--phone" in INSTALL_PS1


def test_wsl_is_kept_running_after_login_without_needing_admin():
    assert "Startup" in INSTALL_PS1          # the user's Startup folder, not a scheduled task
    assert "--headless" in INSTALL_PS1       # no console window left open
    assert "sleep infinity" in INSTALL_PS1


def test_the_pc_does_not_sleep_while_plugged_in():
    assert "powercfg /change standby-timeout-ac 0" in INSTALL_PS1
