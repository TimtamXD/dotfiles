"""Every language Tim's projects use gets a language server, a tree-sitter parser and a formatter.

The projects (Nov 2026): TypeScript/React with Vite, Next, Tailwind, ESLint and Prisma; Rust;
Python; Postgres SQL; Kotlin (Gradle) and Swift for mobile; Docker and Compose; PowerShell and
shell scripts; Markdown, YAML (GitHub workflows), TOML and JSON.

Run: python3 -m pytest tests
"""
import pathlib
import re

NVIM = pathlib.Path(__file__).resolve().parent.parent / "nvim" / "lua" / "config"
LSP = (NVIM / "lsp.lua").read_text()
TREESITTER = (NVIM / "treesitter.lua").read_text()
FORMATTING = (NVIM / "formatting.lua").read_text()


def auto_installed_servers():
    table = re.search(r"local auto_lsp_servers = \{(.*?)\n\}", LSP, re.S).group(1)
    return {name for name, on in re.findall(r"\['(\w+)'\] = ([^,]+),", table) if on.strip() != "false"}


def parsers():
    table = re.search(r"M\.parsers_to_install = vim\.tbl_flatten \{(.*?)\n\}", TREESITTER, re.S).group(1)
    table = re.sub(r"false and \{.*?\},", "", table, flags=re.S)  # the list that is switched off
    return set(re.findall(r'"([a-z_]+)"', table))


def formatted_filetypes():
    return set(re.findall(r"^  cf\.(\w+) =", FORMATTING, re.M))


# --- language servers mason installs the first time a file of that type opens ---

def test_web_projects_get_typescript_html_css_tailwind_eslint_and_emmet():
    assert {"ts_ls", "html", "cssls", "tailwindcss", "eslint", "emmet_language_server"} <= auto_installed_servers()


def test_database_projects_get_sql_and_prisma():
    assert {"sqlls", "prismals"} <= auto_installed_servers()


def test_rust_and_python_projects_get_their_servers():
    assert {"rust_analyzer", "basedpyright", "ruff"} <= auto_installed_servers()


def test_containers_get_dockerfile_and_compose_servers():
    assert {"dockerls", "docker_compose_language_service"} <= auto_installed_servers()


def test_docs_and_config_files_get_markdown_yaml_toml_and_json_servers():
    assert {"marksman", "yamlls", "taplo", "jsonls"} <= auto_installed_servers()


def test_powershell_scripts_get_a_server_where_powershell_is_installed():
    assert re.search(r"\['powershell_es'\] = vim\.fn\.executable\('pwsh'\) == 1", LSP)


def test_swift_uses_the_toolchains_own_sourcekit_lsp_when_it_is_installed():
    assert "vim.fn.executable('sourcekit-lsp') == 1" in LSP
    assert "vim.lsp.enable('sourcekit')" in LSP


# --- tree-sitter parsers ---

def test_every_project_language_has_a_parser():
    assert {
        "typescript", "tsx", "javascript", "html", "css", "sql", "prisma", "rust", "python",
        "kotlin", "dockerfile", "powershell", "bash", "markdown", "yaml", "toml", "json",
    } <= parsers()


# nvim-treesitter builds these from the grammar, which needs the separate `tree-sitter` CLI;
# installing one at startup without it fails on every launch ("tree-sitter CLI not found").
NEEDS_TREE_SITTER_CLI = {"latex", "mlir", "ocamllex", "scfg", "swift", "teal", "unison"}


def test_no_parser_installed_at_startup_needs_the_tree_sitter_cli():
    assert parsers() & NEEDS_TREE_SITTER_CLI == set()


def test_the_install_prompt_skips_parsers_this_machine_cannot_build():
    support = (NVIM / "language_support.lua").read_text()
    assert "requires_generate_from_grammar" in support
    assert "vim.fn.executable('tree-sitter')" in support


# --- formatters (format-on-save stays opt-in per project) ---

def test_react_files_and_web_assets_are_formatted_with_prettier():
    for ft in ("typescriptreact", "javascriptreact", "css", "html", "json", "yaml", "markdown"):
        assert ft in formatted_filetypes(), ft
        assert re.search(rf"cf\.{ft} = (prettier|cf\.\w+)", FORMATTING), ft


def test_toml_and_swift_have_formatters():
    assert {"toml", "swift"} <= formatted_filetypes()


# --- fzf: fzf-lua (gr, Ctrl-p, Ctrl-g) and the fzf vim plugin ---

INSTALL_SH = (NVIM.parent.parent.parent / "install.sh").read_text()
UI_PLUGINS = (NVIM.parent / "plugins" / "ui.lua").read_text()


def test_every_machine_gets_fzf_in_home_fzf_not_only_ones_with_an_old_fzf():
    body = re.search(r"^install_fzf\(\) \{.*?^\}", INSTALL_SH, re.S | re.M).group(0)
    assert 'git clone -q --depth 1 https://github.com/junegunn/fzf "$HOME/.fzf"' in body
    assert body.index("$HOME/.fzf") < body.index("version_at_least")  # cloned before the version check


def test_without_home_fzf_the_fzf_plugin_is_installed_by_lazy_instead_of_switched_off():
    assert "Please run `dotfiles update`" not in UI_PLUGINS


def test_ubuntu_gets_what_rust_crates_commonly_link_against():
    # openssl-sys (reqwest, git2, ...) needs pkg-config and the OpenSSL headers to build
    assert re.search(r"apt-get install -y [^\n]*pkg-config[^\n]*libssl-dev", INSTALL_SH)
