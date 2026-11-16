#!/usr/bin/env bash
# One command from a fresh machine to a working setup:
#
#   git clone https://github.com/TimtamXD/dotfiles ~/.dotfiles && ~/.dotfiles/install.sh
#
# It installs the tools (zsh, tmux, neovim, git, ripgrep, fd, fzf, jq, gh, python3, cmake,
# a C compiler, mise for every language runtime, Powerlevel10k and its font), links every
# config, makes zsh the login shell, installs tmux and nvim plugins, the Kotlin language
# server and the iTerm2 theme. Re-running only changes what is missing.
#
#   ./install.sh            everything
#   ./install.sh --no-deps  links, plugins and shell only; no package installs
#   ./install.sh --phone    also: reach this machine from a phone (Tailscale SSH + mosh)
#   ./install.sh --help
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
WITH_DEPS=1
PHONE=0
for arg in "$@"; do
  case "$arg" in
    --no-deps) WITH_DEPS=0 ;;
    --phone)   PHONE=1 ;;
    --help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         printf 'unknown option %s (see --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }

# --- platform detection ---
OS="$(uname -s)"; IS_WSL=0
if [[ "$OS" == "Linux" ]] && grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then IS_WSL=1; fi
case "$OS" in
  Darwin) PLATFORM="macOS" ;;
  Linux)  PLATFORM=$([[ "$IS_WSL" == 1 ]] && echo "WSL" || echo "Linux") ;;
  *) warn "Unsupported OS '$OS'. Native Windows: use WSL (wsl --install) and run this inside it."; exit 1 ;;
esac
ARCH="$(uname -m)"
[[ "$OS" == "Darwin" && "$(sysctl -n hw.optional.arm64 2>/dev/null)" == 1 ]] && ARCH=arm64  # a Rosetta shell says x86_64
info "platform: $PLATFORM ($ARCH)"

link() {  # link <source-in-repo> <target>
  local src="$DOTFILES/$1" dst="$2"
  [[ -e "$src" ]] || { warn "missing $src, skipping"; return; }
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    [[ "$(readlink "$dst")" == "$src" ]] && return
    rm "$dst"
  elif [[ -e "$dst" ]]; then mv "$dst" "$dst.bak-$TS"; warn "backed up $dst -> $dst.bak-$TS"; fi
  ln -s "$src" "$dst"
  info "linked $dst -> $src"
}

brew_arm() { [[ "$ARCH" == arm64 && -x /opt/homebrew/bin/brew ]] && arch -arm64 /opt/homebrew/bin/brew "$@" || brew "$@"; }

install_fonts() {  # MesloLGS NF: what the prompt and the tmux status bar draw their glyphs with
  local dir="$HOME/Library/Fonts"; [[ "$OS" == "Linux" ]] && dir="$HOME/.local/share/fonts"
  mkdir -p "$dir"
  local f; for f in Regular Bold Italic "Bold Italic"; do
    [[ -f "$dir/MesloLGS NF $f.ttf" ]] || curl -fsSL -o "$dir/MesloLGS NF $f.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${f// /%20}.ttf" || warn "font $f did not download"
  done
  [[ "$OS" == "Linux" ]] && command -v fc-cache >/dev/null && fc-cache -f "$dir" >/dev/null || true
}

version_at_least() {  # version_at_least <minimum> <version>
  [[ -n "$2" && "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

install_fzf() {  # ~/.fzf: nvim's fzf plugin loads from it; its fzf binary replaces a packaged one
  # older than 0.36, which fzf-lua (gr, Ctrl-p, Ctrl-g) needs (Ubuntu 20.04 ships 0.20, 22.04 0.29)
  if [[ -d "$HOME/.fzf/.git" ]]; then
    git -C "$HOME/.fzf" pull -q --ff-only || true
  else
    git clone -q --depth 1 https://github.com/junegunn/fzf "$HOME/.fzf"
  fi
  "$HOME/.fzf/install" --bin >/dev/null || { warn "fzf did not install"; return; }
  local v; v="$(fzf --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || true)"
  version_at_least 0.36 "$v" && return
  info "fzf ${v:-missing} is too old; using ~/.fzf/bin/fzf"
  sudo ln -sf "$HOME/.fzf/bin/fzf" /usr/local/bin/fzf   # /usr/local/bin comes before /usr/bin everywhere
  hash -r
}

warn_old_tmux() {  # popups (prefix+t), allow-passthrough and extended-keys need tmux 3.3+
  local v; v="$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || true)"
  version_at_least 3.3 "$v" && return
  warn "tmux ${v:-missing} is older than the 3.3 this config needs (Ubuntu 22.04 and older)."
  [[ "$IS_WSL" == 1 ]] && warn "  In PowerShell: wsl --install -d Ubuntu-24.04; wsl --set-default Ubuntu-24.04; then re-run install.ps1."
}

install_nvim_release() {  # distro packages lag: Ubuntu 24.04 ships 0.9, and this config switches off below 0.10
  local v; v="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
  [[ -n "$v" && "$(printf '%s\n' 0.11 "$v" | sort -V | head -1)" == 0.11 ]] && return
  local arch=x86_64; [[ "$ARCH" == aarch64 || "$ARCH" == arm64 ]] && arch=arm64
  info "installing the latest Neovim release to /opt/nvim (the packaged one is ${v:-missing})"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz" \
    || { warn "Neovim download failed"; rm -rf "$tmp"; return; }
  tar -C "$tmp" -xzf "$tmp/nvim.tar.gz"
  sudo rm -rf /opt/nvim && sudo mv "$tmp/nvim-linux-$arch" /opt/nvim
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim   # /usr/local/bin comes before /usr/bin everywhere
  rm -rf "$tmp"; hash -r
}

install_gh_apt() {  # GitHub's own apt repo: Ubuntu's archive can give an old gh, or an unrelated tool named gh
  gh --version 2>/dev/null | grep -q '^gh version' && return
  info "installing GitHub CLI from cli.github.com"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update && sudo apt-get install -y gh || warn "GitHub CLI did not install"
  hash -r
  gh --version 2>/dev/null | grep -q '^gh version' \
    || warn "another 'gh' is first on PATH: $(command -v gh); remove it (pip uninstall gh / pipx uninstall gh)"
}

install_deps() {
  local core="zsh tmux neovim git ripgrep fd fzf jq gh python3 curl unzip cmake"
  if [[ "$OS" == "Darwin" ]]; then
    xcode-select -p >/dev/null 2>&1 || { info "installing the Xcode command line tools (clang, make)"; xcode-select --install || true; }
    if ! command -v brew >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/brew ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    brew_arm install $core mise powerlevel10k || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y zsh tmux neovim git ripgrep fd-find fzf jq python3 python3-venv curl unzip cmake build-essential clang pkg-config libssl-dev || true
    install_gh_apt
    command -v fdfind >/dev/null 2>&1 && mkdir -p "$HOME/bin" && ln -sf "$(command -v fdfind)" "$HOME/bin/fd"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y zsh tmux neovim git ripgrep fd-find fzf jq gh python3 curl unzip cmake gcc-c++ clang || true
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm zsh tmux neovim git ripgrep fd fzf jq github-cli python curl unzip cmake base-devel clang || true
  else
    warn "No known package manager found — install $core manually."
  fi
  if [[ "$OS" != "Darwin" ]]; then
    command -v mise >/dev/null 2>&1 || { info "installing mise"; curl -fsSL https://mise.run | sh; }
    [[ -d "$HOME/.local/share/powerlevel10k" ]] || git clone --depth 1 https://github.com/romkatv/powerlevel10k "$HOME/.local/share/powerlevel10k"
  fi
  [[ "$OS" == "Linux" ]] && install_nvim_release
  install_fzf
  export PATH="$HOME/.local/bin:$PATH"
  if [[ "$IS_WSL" == 1 ]]; then
    warn "WSL: install the MesloLGS NF font on the Windows side and pick it in Windows Terminal."
  else
    install_fonts
  fi
}

[[ "$WITH_DEPS" == 1 ]] && { info "installing tools"; install_deps; }

info "linking configs"
link nvim              "$HOME/.config/nvim"
link vim               "$HOME/.vim"
link vim/vimrc         "$HOME/.vimrc"
link tmux/tmux.conf    "$HOME/.tmux.conf"
link zsh/zshrc         "$HOME/.zshrc"
link zsh/zshenv        "$HOME/.zshenv"
link zsh/p10k.zsh      "$HOME/.p10k.zsh"
link git/gitconfig     "$HOME/.gitconfig"
link mise/config.toml  "$HOME/.config/mise/config.toml"
link claude/skills/nvim "$HOME/.claude/skills/nvim"
[[ -f "$DOTFILES/git/gitignore_global" ]] && link git/gitignore_global "$HOME/.gitignore_global"

# WSL: repos on the Windows side (/mnt/c/...) are checked out with CRLF by Windows git; without
# this every file in them shows as modified. ~/.gitconfig is the repo's file, so it goes in the
# machine-local one it includes.
if [[ "$IS_WSL" == 1 ]]; then
  git config --file "$HOME/.gitconfig.local" core.autocrlf input
fi

# Terminal emulator configs: desktop only. On WSL the GUI terminal runs on
# Windows, so linking these into the WSL home is pointless — skip.
if [[ "$IS_WSL" == 0 ]]; then
  for t in alacritty kitty wezterm; do
    [[ -d "$DOTFILES/terminal/$t" ]] && link "terminal/$t" "$HOME/.config/$t"
  done
fi

# ~/.zshrc.local for secrets (never tracked)
if [[ ! -f "$HOME/.zshrc.local" ]]; then
  cp "$DOTFILES/zsh/zshrc.local.example" "$HOME/.zshrc.local"
  warn "created ~/.zshrc.local — fill in your secrets there (it is gitignored)"
fi

# zsh as the login shell
if [[ "$(basename "${SHELL:-}")" != "zsh" ]] && command -v zsh >/dev/null 2>&1; then
  if [[ -t 0 ]]; then info "making zsh the login shell"; chsh -s "$(command -v zsh)" || warn "chsh failed; run: chsh -s $(command -v zsh)"
  else warn "login shell is not zsh; run: chsh -s $(command -v zsh)"; fi
fi

# language runtimes from mise/config.toml (node, python, java, rust, go); projects override per directory
if command -v mise >/dev/null 2>&1 && [[ "$WITH_DEPS" == 1 ]]; then
  info "installing language runtimes with mise (this is the slow step the first time)"
  mise install --yes || warn "mise install had trouble; run: mise install"
fi

# tmux plugin manager
TPM="$HOME/.tmux/plugins/tpm"
[[ -d "$TPM" ]] || { info "installing tpm"; git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"; }
"$TPM/bin/install_plugins" >/dev/null 2>&1 || warn "run prefix+I inside tmux to finish plugin install"
tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true   # a running server picks the config up now

# nvim: sync plugins headless (lazy.nvim bootstraps itself from init.lua); language servers
# install themselves through mason the first time nvim opens.
if command -v nvim >/dev/null 2>&1; then
  info "syncing nvim plugins (headless)"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "open nvim and run :Lazy sync"
  # everyday language servers up front; :MasonInstall blocks until done when headless
  servers=$(sed 's/#.*//' "$DOTFILES/nvim/mason-packages.txt" | xargs)
  info "installing language servers: $servers"
  nvim --headless -c "lua require('lazy').load({ plugins = { 'mason.nvim' } }); require('mason').setup()" \
    -c "MasonInstall $servers" -c qa 2>&1 | tail -5 || warn "some language servers did not install; open nvim and run :Mason"
else
  warn "nvim not installed — re-run without --no-deps, or install it, then re-run."
fi

# Kotlin language server (JetBrains builds expire monthly; nvim keeps this fresh via :KotlinLspUpdate)
"$DOTFILES/bin/kotlin-lsp-update" || warn "kotlin-lsp did not install; run bin/kotlin-lsp-update later"

# iTerm2: IntelliJ Dark colours, MesloLGS NF, minimal tabs
if [[ "$OS" == "Darwin" && -f "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]]; then
  "$DOTFILES/bin/iterm2-theme" || warn "iTerm2 theme not applied; run bin/iterm2-theme"
fi

warn_old_tmux

setup_phone_access() {  # Tailscale (with its SSH: no keys) + mosh, so a phone can reach tmux here
  if [[ "$OS" == "Darwin" ]]; then
    warn "phone access on macOS: install the Tailscale app and turn on Remote Login in System Settings"
    return
  fi
  if [[ "$(ps -p 1 -o comm= 2>/dev/null)" != systemd ]]; then  # tailscaled runs as a systemd service
    warn "WSL is running without systemd, which Tailscale needs. Turning it on:"
    grep -q '^systemd=true' /etc/wsl.conf 2>/dev/null \
      || printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
    warn "  now run  wsl --shutdown  in PowerShell, then this installer again"
    return
  fi
  command -v tailscale >/dev/null || { info "installing Tailscale"; curl -fsSL https://tailscale.com/install.sh | sh; }
  command -v mosh-server >/dev/null || sudo apt-get install -y mosh
  local name; name="$(hostname | tr '[:upper:]' '[:lower:]')-wsl"
  if tailscale status >/dev/null 2>&1; then
    sudo tailscale set --ssh
  else
    info "sign in to Tailscale: open the link below (on any device), then come back"
    sudo tailscale up --ssh --hostname "$name"
  fi
  info "phone access ready. On the iPhone: Tailscale app (same account), then in Termius or Blink:"
  info "  mosh $(whoami)@$name      then  phone   (your tmux session, the same one as at the PC)"
}
[[ "$PHONE" == 1 ]] && setup_phone_access

info "done."
cat <<MSG
  next:  exec zsh            (or open a new terminal window)
         dev                 in any project: what it can run and what is running
         prefix + t in tmux  the dev command center
MSG
