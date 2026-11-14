"""How cv opens a Windows project in WSL's Neovim, from the Claude app on Windows.

Run: python3 -m pytest tests
"""
import importlib.machinery
import importlib.util
import pathlib

CV_PATH = pathlib.Path(__file__).resolve().parent.parent / "bin" / "cv"
_loader = importlib.machinery.SourceFileLoader("cv", str(CV_PATH))
_spec = importlib.util.spec_from_loader("cv", _loader)
cv = importlib.util.module_from_spec(_spec)
_loader.exec_module(cv)


# --- a Windows path becomes the same folder as WSL sees it ---

def test_a_windows_path_with_backslashes_opens_under_mnt():
    assert cv.wsl_path(r"C:\Users\tim\repos\shop") == "/mnt/c/Users/tim/repos/shop"


def test_a_windows_path_with_forward_slashes_opens_under_mnt():
    assert cv.wsl_path("D:/work/api") == "/mnt/d/work/api"


def test_the_drive_letter_is_lower_case_like_wsl_mounts_it():
    assert cv.wsl_path("E:\\") == "/mnt/e"


def test_a_linux_path_is_left_alone():
    assert cv.wsl_path("/home/tim/repos/shop") == "/home/tim/repos/shop"


def test_a_relative_path_is_left_alone():
    assert cv.wsl_path("repos/shop") == "repos/shop"


# --- opening Windows Terminal on the tmux session ---

def test_windows_terminal_opens_a_tab_attached_to_the_tmux_session():
    assert cv.windows_terminal_attach("0", "Ubuntu") == [
        "wt.exe", "-w", "0", "new-tab", "--title", "nvim",
        "wsl.exe", "-d", "Ubuntu", "--exec", "tmux", "attach-session", "-t", "0",
    ]


def test_without_a_distro_name_windows_terminal_uses_the_default_distro():
    assert cv.windows_terminal_attach("dev", None) == [
        "wt.exe", "-w", "0", "new-tab", "--title", "nvim",
        "wsl.exe", "--exec", "tmux", "attach-session", "-t", "dev",
    ]


# --- the picker finds the Claude app's Windows sessions too ---

def test_the_picker_looks_in_the_windows_claude_app_folder_from_wsl():
    assert "/mnt/c/Users/*/AppData/Roaming/Claude/claude-code-sessions/*/*/local_*.json" in cv.SESSION_GLOBS


def test_the_picker_still_looks_in_the_mac_claude_app_folder():
    assert any("Library/Application Support/Claude" in g for g in cv.SESSION_GLOBS)


# --- a worktree the Windows Claude app made still works from WSL ---

def write_worktree(tmp_path, gitdir_line):
    tree = tmp_path / "shop" / ".claude" / "worktrees" / "fix-cart"
    (tree / "src").mkdir(parents=True)
    (tree / ".git").write_text(gitdir_line + "\n")
    return tree


def test_a_worktree_pointing_at_a_windows_gitdir_gets_git_pointed_at_the_wsl_path(tmp_path):
    tree = write_worktree(tmp_path, "gitdir: C:/Users/tim/repos/shop/.git/worktrees/fix-cart")
    assert cv.git_env(str(tree / "src")) == {
        "GIT_DIR": "/mnt/c/Users/tim/repos/shop/.git/worktrees/fix-cart",
        "GIT_WORK_TREE": str(tree),
    }


def test_a_worktree_with_a_linux_gitdir_needs_nothing(tmp_path):
    tree = write_worktree(tmp_path, "gitdir: /home/tim/shop/.git/worktrees/fix-cart")
    assert cv.git_env(str(tree)) == {}


def test_a_worktree_with_a_relative_gitdir_needs_nothing(tmp_path):
    tree = write_worktree(tmp_path, "gitdir: ../../../.git/worktrees/fix-cart")
    assert cv.git_env(str(tree)) == {}


def test_an_ordinary_repo_needs_nothing(tmp_path):
    (tmp_path / ".git").mkdir()
    assert cv.git_env(str(tmp_path)) == {}


def test_a_folder_outside_any_repo_needs_nothing(tmp_path):
    assert cv.git_env(str(tmp_path)) == {}
