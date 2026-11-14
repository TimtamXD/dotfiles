"""kotlin-lsp-update picks the JetBrains build for this machine.

Run: python3 -m pytest tests
"""
import pathlib
import subprocess

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "bin" / "kotlin-lsp-update"


def archive(os_name, arch, version="262.9593.0"):
    r = subprocess.run([str(SCRIPT), "--archive-name", os_name, arch, version], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return r.stdout.strip()


def test_an_x86_64_linux_box_or_wsl_gets_the_plain_linux_build():
    assert archive("Linux", "x86_64") == "kotlin-server-262.9593.0.tar.gz"


def test_an_arm_linux_box_gets_the_aarch64_build():
    assert archive("Linux", "aarch64") == "kotlin-server-262.9593.0-aarch64.tar.gz"


def test_an_apple_silicon_mac_gets_the_aarch64_mac_build():
    assert archive("Darwin", "arm64") == "kotlin-server-262.9593.0-aarch64.sit"


def test_an_intel_mac_gets_the_plain_mac_build():
    assert archive("Darwin", "x86_64") == "kotlin-server-262.9593.0.sit"
