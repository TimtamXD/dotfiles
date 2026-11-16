# dotfiles

One command turns a fresh Mac, Linux box, Windows PC or WSL into my working setup: zsh with a
Powerlevel10k prompt, tmux, Neovim with language servers, every language runtime
through mise, and `dev`, a command center that runs anything in a project and shows
what is running.

## Quick start

```bash
git clone https://github.com/TimtamXD/dotfiles ~/.dotfiles && ~/.dotfiles/install.sh
```

On Windows, from PowerShell (sets up Windows, then runs `install.sh` inside WSL if a
distro is installed):

```powershell
irm https://raw.githubusercontent.com/TimtamXD/dotfiles/main/install.ps1 | iex
```

Then `exec zsh` (or open a new Windows Terminal tab). The installer is idempotent and non-destructive: it only installs what
is missing, and any file it replaces is kept as `<file>.bak-<timestamp>`. Secrets go in
`~/.zshrc.local`, which it creates from `zsh/zshrc.local.example` and never commits.
`install.sh --no-deps` links configs and plugins without touching packages.

Pick **MesloLGS NF** as the terminal font if the prompt shows boxes. On macOS the
installer sets it in iTerm2 along with the IntelliJ Dark colours (`bin/iterm2-theme`).

## Daily use

### `dev`: run anything, see everything

| Command | Does |
|---|---|
| `dev` | status of every task the project knows: running or not, since when, ports, exit codes, code changed since start |
| `dev run` | pick a task with fzf and start it in its own tmux window |
| `dev admin` | start the task called `admin` (`dev run admin` works too; `-- args` go to the command) |
| `dev exec name -- cmd…` | run any command as a tracked task |
| `dev stop` / `restart` / `logs -f` / `open` | manage one task |
| `dev top` | live status; in tmux it is `prefix + t`, and `prefix + T` picks a task to run |
| `dev tasks` | every task and where it was found |
| `dev clean` | close the windows of finished tasks and drop old logs |

Tasks come from `.dev.toml` at the project root (`dev init` writes one), from
`dev/projects/*.toml` in this repo for projects I do not want to add files to, and
automatically from Makefiles, `package.json` scripts, `Cargo.toml`, justfiles and Gradle
application projects. Every task runs in the `dev` tmux session, keeps its output in a
window after it ends, and logs to `~/.local/state/dev/<project>/logs/`.

### Finding your way in nvim

`,` is the leader. Fuzzy find with `Ctrl-p` (files) and `Ctrl-g` (text), `,rg` greps the
word under the cursor. Language-server jumps: `gd` definition, `gr` references, `gi`
implementations, `gp` peek, `K` docs, `]d` `[d` diagnostics, `,rn` rename, `,ca` code
actions. `,f` plus a character jumps anywhere on screen. `,E` toggles the file tree.
`Ctrl-h/j/k/l` moves between splits and tmux panes. `:Maps` searches every binding.

### tmux

Window names say where you are and what runs there (`platform`, `platform:nvim`,
`servers:java`); split windows show each pane's directory and command on its border.
The status bar shows the session, the pane's directory, its git branch and the time.
`prefix + |` and `prefix + -` split, `prefix + r` reloads the config, `prefix + Ctrl-s`
and `prefix + Ctrl-r` save and restore sessions (they also survive reboots).

## Languages

`mise/config.toml` installs Node (LTS and 18), Python, Java (Corretto 21), Rust and Go
globally; a project's `.mise.toml`, `.nvmrc` or `.java-version` wins inside it. Neovim
installs a language server through mason the first time it opens that kind of file:

| Projects | Servers |
|---|---|
| TypeScript/JavaScript, React, Vite/Next | `ts_ls`, `eslint`, `tailwindcss`, `html`, `cssls`, `emmet_language_server` |
| Databases | `sqlls`, `prismals` |
| Rust, Python, Go, C/C++ | `rust_analyzer`, `basedpyright` + `ruff`, `gopls`, `clangd` |
| Kotlin, Java | JetBrains' `kotlin-lsp` (arm64 and x64), `jdtls` |
| Swift | `sourcekit-lsp` from the Swift toolchain, when installed |
| Docker, shell, PowerShell | `dockerls`, `docker_compose_language_service`, `bashls`, `powershell_es` (where `pwsh` exists) |
| Markdown, YAML, TOML, JSON, XML, Lua, LaTeX | `marksman`, `yamlls`, `taplo`, `jsonls`, `lemminx`, `lua_ls`, `texlab` |

Any other language asks the first time you open one of its files: pick a server and Neovim
installs it and the tree-sitter parser in the background, with a progress bar, then attaches
the server to the open files. "Never ask" is remembered per filetype; `:LanguageSupport`
asks again (or `:LanguageSupport <filetype>`). Works the same on macOS, Linux, WSL and Windows.

Formatting (`:Format`; on save once enabled for a project) uses prettier for web files and
JSON/YAML/Markdown, ruff, rustfmt, gofmt, clang-format, ktlint, taplo, swift-format and
pg_format. Kotlin's kotlin-lsp builds expire monthly: nvim replaces it by itself, or run
`:KotlinLspUpdate`.

To add a language: a line in `mise/config.toml`, its server in `auto_lsp_servers`
(`nvim/lua/config/lsp.lua`), its parser in `nvim/lua/config/treesitter.lua`, its
formatter in `nvim/lua/config/formatting.lua`; `tests/test_language_support.py` lists
what the projects need.

## What's included

| Path | Links to | Notes |
|------|----------|-------|
| `nvim/` | `~/.config/nvim` | lazy.nvim bootstraps itself; `lazy-lock.json` pins versions |
| `vim/` | `~/.vim`, `~/.vimrc` | the vimrc nvim sources for its basic settings and keymaps |
| `tmux/tmux.conf` | `~/.tmux.conf` | tpm + resurrect/continuum; installer clones tpm |
| `zsh/zshrc`, `zsh/zshenv`, `zsh/p10k.zsh` | `~/.zshrc`, `~/.zshenv`, `~/.p10k.zsh` | secrets sourced from `~/.zshrc.local` |
| `powershell/profile.ps1` | `Documents\PowerShell\profile.ps1` (and `WindowsPowerShell`) | Windows only |
| `git/gitconfig` | `~/.gitconfig` | uses `gh` as the credential helper |
| `mise/config.toml` | `~/.config/mise/config.toml` | global language runtimes |
| `terminal/{alacritty,kitty,wezterm}` | `~/.config/*` | desktop only; skipped on WSL |
| `bin/dev` | on `$PATH` | the command center |
| `bin/kotlin-lsp-update` | on `$PATH` | reinstalls JetBrains' kotlin-lsp when a build expires |
| `bin/iterm2-theme` | on `$PATH` | iTerm2 colours, font and tab style (macOS) |
| `bin/cv` | on `$PATH` | pick a Claude app session's branch and open its worktree in Neovim, in a tmux window (iTerm2 on macOS; on Windows, WSL's Neovim in a Windows Terminal tab, and it takes `C:\` paths) |
| `bin/nvim-check` | on `$PATH` | smoke-tests Neovim and its plugins after an upgrade |
| `claude/skills/nvim` | `~/.claude/skills/nvim` | `/nvim` in a Claude session runs `cv` on that session's worktree |
| `dev/projects/*.toml` | read by `dev` | task definitions for projects, matched by `root` |

## Claude in Neovim

[claudecode.nvim](https://github.com/coder/claudecode.nvim) runs Claude Code in a split beside
your code, signed in with your Claude account (no API key). It sees the open file and your
selection, searches the project, and proposes edits as diffs. `,` is the leader key:

| Keys | Does |
|---|---|
| `,ac` | open / close Claude: ask anything ("where's the fair value calculated?") |
| `,as` | send the selection (visual mode); in the file tree, add the file under the cursor |
| `,ab` | add the current file |
| `,aa` / `,ad` | accept / reject the edit Claude proposed |
| `,af` · `,ar` · `,aC` · `,am` | jump to Claude · resume a chat · continue the last · pick a model |

`install.sh` installs Claude Code if `claude` isn't there; sign in once by running `claude`.

## From a phone

Your PC's WSL, tmux and Neovim from an iPhone, over [Tailscale](https://tailscale.com) (a
private network; nothing is exposed to the internet) with its SSH (no keys).

At the PC, once, in PowerShell:

```powershell
$env:DOTFILES_PHONE=1; irm https://raw.githubusercontent.com/TimtamXD/dotfiles/main/install.ps1 | iex
```

It installs Tailscale (sign in when it shows a link) and mosh in WSL, keeps WSL running after
you log in (a hidden session started from the Startup folder) and stops the PC sleeping while
plugged in. On another Linux box: `./install.sh --phone`.

On the iPhone: the Tailscale app (same account), and Termius (free) or Blink Shell. Connect
with `mosh <you>@<pc>-wsl` (mosh survives network changes and the phone sleeping; plain SSH
works too), then run `phone`: the tmux session `main`, the same one the PC sees.

## Tests

`python3 -m pytest tests` (which also runs `tests/*_spec.lua` with `nvim -l` where Neovim is
installed) checks how new languages are offered, that every project language has a server, parser and
formatter, how `cv` opens Windows projects in WSL, and which kotlin-lsp build each machine gets.

## Secrets

**No credentials live in this repo.** `~/.zshrc` sources `~/.zshrc.local`, which is
gitignored. On first run the installer copies `zsh/zshrc.local.example` to
`~/.zshrc.local` for you to fill in (Maven keys, DB creds, cloud auth, etc.).

## Platform notes

- **macOS** — Homebrew (installed if missing), the Xcode command line tools for C/C++,
  fonts into `~/Library/Fonts`, iTerm2 themed.
- **Linux** — `apt`, `dnf` or `pacman` (auto-detected); Powerlevel10k and mise from
  their installers; fonts into `~/.local/share/fonts`.
- **Windows** — `install.ps1` installs git, neovim, ripgrep, fd, fzf, jq, gh, mise, cmake
  and zig (the tree-sitter compiler) with winget; links nvim to `%LOCALAPPDATA%\nvim`,
  `.vimrc`, `.gitconfig`, mise, wezterm, alacritty and a small PowerShell profile
  (`powershell/profile.ps1`, secrets in `~/.profile.local.ps1`); puts mise's shims on
  PATH; installs MesloLGS NF and selects it in Windows Terminal. Links are symlinks when
  Developer Mode is on, otherwise junctions and hard links — after a `git pull`, re-run
  the installer to refresh hard-linked files. zsh, tmux and `dev` need WSL.
  Options: `$env:DOTFILES_NO_DEPS=1` (no package installs), `$env:DOTFILES_SKIP_WSL=1`.
- **WSL** — treated as Linux; `install.ps1` runs `install.sh` in your default distro, or run
  the quick start inside it. Fonts and terminal configs live on the Windows side. No distro
  yet: `wsl --install` in an admin PowerShell, reboot, re-run.

## Credits

The Neovim configuration is adapted from
[wookayin/dotfiles](https://github.com/wookayin/dotfiles). Thanks!

## License

MIT — see [LICENSE](LICENSE).
