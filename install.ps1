# One command from PowerShell sets up Windows and, if it is installed, WSL:
#
#   irm https://raw.githubusercontent.com/TimtamXD/dotfiles/main/install.ps1 | iex
#
# On Windows it installs the tools with winget (git, neovim, ripgrep, fd, fzf, jq, gh, mise,
# cmake, zig as the tree-sitter compiler), clones this repo to ~/.dotfiles, links every config
# that makes sense on Windows, installs the MesloLGS NF font and selects it in Windows Terminal,
# and installs the mise runtimes and nvim plugins. Then, in every WSL distro's default one,
# it clones the repo and runs install.sh. Re-running only changes what is missing.
#
# Options (from a clone:  .\install.ps1 -NoDeps), or as environment variables when piped:
#   -NoDeps   / $env:DOTFILES_NO_DEPS=1   links and plugins only; no package installs
#   -SkipWsl  / $env:DOTFILES_SKIP_WSL=1  Windows side only

$RepoUrl = 'https://github.com/TimtamXD/dotfiles'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Blue }
function Write-Warn([string]$Message) { Write-Host "!   $Message" -ForegroundColor Yellow }
function Test-Command([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user"
}

function Add-UserPath([string]$Dir) {
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $user) { $user = '' }
  if (($user -split ';') -notcontains $Dir) {
    [Environment]::SetEnvironmentVariable('Path', ($user.TrimEnd(';') + ";$Dir").TrimStart(';'), 'User')
    Write-Step "added $Dir to your PATH"
  }
  Update-SessionPath
}

# --- packages ---------------------------------------------------------------------------

# winget id -> the command that proves it is already installed
$Packages = [ordered]@{
  'Git.Git'                    = 'git'
  'Neovim.Neovim'              = 'nvim'
  'BurntSushi.ripgrep.MSVC'    = 'rg'
  'sharkdp.fd'                 = 'fd'
  'junegunn.fzf'               = 'fzf'
  'jqlang.jq'                  = 'jq'
  'GitHub.cli'                 = 'gh'
  'jdx.mise'                   = 'mise'
  'Kitware.CMake'              = 'cmake'
  'zig.zig'                    = 'zig'
}

function Install-Package([string]$Id, [string]$Command) {
  if (Test-Command $Command) { return }
  Write-Step "installing $Id"
  winget install --id $Id --exact --source winget --silent `
    --accept-package-agreements --accept-source-agreements | Out-Host
  if ($LASTEXITCODE -ne 0) { Write-Warn "winget could not install $Id (exit $LASTEXITCODE)" }
  Update-SessionPath
}

function Install-Packages {
  if (-not (Test-Command 'winget')) {
    Write-Warn 'winget is missing: install "App Installer" from the Microsoft Store, then re-run.'
    return
  }
  foreach ($id in $Packages.Keys) { Install-Package $id $Packages[$id] }
}

# --- the repo ---------------------------------------------------------------------------

function Get-Dotfiles {
  if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '.git'))) { return $PSScriptRoot }
  $dir = Join-Path $HOME '.dotfiles'
  if (Test-Path (Join-Path $dir '.git')) {
    Write-Step "updating $dir"
    git -C $dir pull --ff-only | Out-Host
  } else {
    if (-not (Test-Command 'git')) { Install-Package 'Git.Git' 'git' }
    Write-Step "cloning $RepoUrl into $dir"
    git clone $RepoUrl $dir | Out-Host
  }
  return $dir
}

# --- links ------------------------------------------------------------------------------

function Test-SameLink($Item, [string]$Source) {
  $Item.LinkType -and (@($Item.Target) -contains $Source)
}

function New-Link([string]$Source, [string]$Target) {
  # Symlink when Windows allows it (Developer Mode or admin); otherwise a junction for
  # folders and a hard link for files. Hard links go stale when git rewrites the file,
  # so re-run the installer after pulling.
  $isDir = Test-Path $Source -PathType Container
  try {
    New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
  } catch {
    $type = if ($isDir) { 'Junction' } else { 'HardLink' }
    New-Item -ItemType $type -Path $Target -Target $Source -ErrorAction Stop | Out-Null
  }
}

function Set-Link([string]$Dotfiles, [string]$RepoPath, [string]$Target) {
  $source = [IO.Path]::GetFullPath((Join-Path $Dotfiles $RepoPath))
  $Target = [IO.Path]::GetFullPath($Target)
  if (-not (Test-Path $source)) { Write-Warn "missing $source, skipping"; return }
  New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
  $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
  if ($existing) {
    if (Test-SameLink $existing $source) { return }
    $isLink = $existing.LinkType -and $existing.LinkType -ne 'HardLink'
    $isOurHardLink = $existing.LinkType -eq 'HardLink' -and -not $existing.PSIsContainer -and
      (Test-Path $source -PathType Leaf) -and
      (Get-FileHash $existing.FullName).Hash -eq (Get-FileHash $source).Hash
    if ($isLink -or $isOurHardLink) {
      $existing.Delete()
    } else {
      Move-Item -LiteralPath $Target "$Target.bak-$Stamp"
      Write-Warn "backed up $Target -> $Target.bak-$Stamp"
    }
  }
  New-Link $source $Target
  Write-Step "linked $Target -> $source"
}

function Enable-Profile {
  # Windows ships with scripts disabled, so the linked profile fails to load in every new window.
  # RemoteSigned for this user only runs local scripts and signed downloaded ones; no admin needed.
  if ((Get-ExecutionPolicy) -in 'Restricted', 'AllSigned', 'Undefined') {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Step 'PowerShell may now run local scripts like your profile (RemoteSigned, this user only)'
  }
}

function Set-Links([string]$Dotfiles) {
  $docs = [Environment]::GetFolderPath('MyDocuments')   # follows OneDrive redirection
  $links = [ordered]@{
    'nvim'                    = Join-Path $env:LOCALAPPDATA 'nvim'
    'vim'                     = Join-Path $HOME '.vim'
    'vim/vimrc'               = Join-Path $HOME '.vimrc'
    'git/gitconfig'           = Join-Path $HOME '.gitconfig'
    'mise/config.toml'        = Join-Path $HOME '.config/mise/config.toml'
    'claude/skills/nvim'      = Join-Path $HOME '.claude/skills/nvim'
    'terminal/wezterm'        = Join-Path $HOME '.config/wezterm'
    'terminal/alacritty'      = Join-Path $env:APPDATA 'alacritty'
    'powershell/profile.ps1'  = Join-Path $docs 'PowerShell/profile.ps1'
  }
  foreach ($repoPath in $links.Keys) { Set-Link $Dotfiles $repoPath $links[$repoPath] }
  # Windows PowerShell 5.1 reads its profile from a different folder
  Set-Link $Dotfiles 'powershell/profile.ps1' (Join-Path $docs 'WindowsPowerShell/profile.ps1')
}

# --- font and terminal ------------------------------------------------------------------

function Install-Fonts {
  $dir = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
  $registry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  if (-not (Test-Path $registry)) { New-Item -Path $registry -Force | Out-Null }
  foreach ($style in 'Regular', 'Bold', 'Italic', 'Bold Italic') {
    $file = Join-Path $dir "MesloLGS NF $style.ttf"
    if (-not (Test-Path $file)) {
      $url = 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20' +
        ($style -replace ' ', '%20') + '.ttf'
      try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $file }
      catch { Write-Warn "font $style did not download"; continue }
    }
    Set-ItemProperty -Path $registry -Name "MesloLGS NF $style (TrueType)" -Value $file
  }
}

function Set-TerminalFont {
  $settings = Join-Path $env:LOCALAPPDATA 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'
  if (-not (Test-Path $settings)) { return }
  try {
    $json = Get-Content $settings -Raw | ConvertFrom-Json
    $defaults = $json.profiles.defaults
    if (-not $defaults) {
      $defaults = [pscustomobject]@{}
      $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue $defaults -Force
    }
    if ($defaults.font.face -eq 'MesloLGS NF') { return }
    Copy-Item $settings "$settings.bak-$Stamp"
    if ($defaults.font) {
      $defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'MesloLGS NF' -Force
    } else {
      $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = 'MesloLGS NF' }) -Force
    }
    $json | ConvertTo-Json -Depth 32 | Set-Content -Encoding UTF8 $settings
    Write-Step 'Windows Terminal now uses MesloLGS NF'
  } catch {
    Write-Warn 'could not edit Windows Terminal settings; pick "MesloLGS NF" as its font yourself'
  }
}

# --- runtimes and plugins ---------------------------------------------------------------

function Install-Runtimes {
  if (-not (Test-Command 'mise')) { return }
  Add-UserPath (Join-Path $env:LOCALAPPDATA 'mise/shims')   # node, python, java… for every program
  Write-Step 'installing language runtimes with mise (the slow step the first time)'
  mise install --yes | Out-Host
  if ($LASTEXITCODE -ne 0) { Write-Warn 'mise install had trouble; run: mise install' }
}

function Install-NvimPlugins([string]$Dotfiles) {
  if (-not (Test-Command 'nvim')) { Write-Warn 'nvim is not installed; re-run without -NoDeps'; return }
  Write-Step 'syncing nvim plugins (headless)'
  $ErrorActionPreference = 'Continue'   # 5.1 turns redirected stderr into terminating errors
  nvim --headless '+Lazy! sync' +qa 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Warn 'open nvim and run :Lazy sync' }
  Install-LanguageServers $Dotfiles
}

function Install-LanguageServers([string]$Dotfiles) {
  # everyday language servers up front; :MasonInstall blocks until done when headless
  $ErrorActionPreference = 'Continue'
  $servers = (Get-Content (Join-Path $Dotfiles 'nvim/mason-packages.txt') |
    ForEach-Object { ($_ -replace '#.*', '').Trim() } | Where-Object { $_ }) -join ' '
  Write-Step "installing language servers: $servers"
  nvim --headless -c "lua require('lazy').load({ plugins = { 'mason.nvim' } }); require('mason').setup()" `
    -c "MasonInstall $servers" -c qa 2>&1 | Select-Object -Last 5 | Out-Host
  if ($LASTEXITCODE -ne 0) { Write-Warn 'some language servers did not install; open nvim and run :Mason' }
}

# --- WSL --------------------------------------------------------------------------------

function Get-WslDistro {
  if (-not (Test-Command 'wsl.exe')) { return $null }
  $ErrorActionPreference = 'Continue'
  # `wsl --list --verbose` marks the default distro with '*'; that is the one `wsl` opens
  $rows = (wsl.exe --list --verbose 2>$null) -replace "`0", '' | Where-Object { $_.Trim() } | Select-Object -Skip 1
  if ($LASTEXITCODE -ne 0 -or -not $rows) { return $null }
  $default = @($rows | Where-Object { $_.TrimStart().StartsWith('*') })[0]
  if (-not $default) { $default = @($rows)[0] }
  return (($default.TrimStart(' ', '*').Trim()) -split '\s+')[0]
}

function Request-WslInstall {
  Write-Warn 'WSL has no Linux distro yet; zsh, tmux, dev and the /nvim skill need one.'
  $answer = Read-Host 'Install Ubuntu in WSL now? (asks for admin, then a reboot) [Y/n]'
  if ($answer -match '^[Nn]') { return }
  Start-Process wsl.exe -ArgumentList '--install', '-d', 'Ubuntu' -Verb RunAs -Wait
  Write-Warn 'reboot, open "Ubuntu" from the Start menu once to create your Linux user, then run this command again.'
}

function Test-WslSetup([string]$Distro) {
  $ErrorActionPreference = 'Continue'
  # no double quotes: Windows PowerShell 5.1 passes them to native programs unescaped
  $check = 'v=$(nvim --version 2>/dev/null | head -1); v=${v#NVIM v}; [ ${#v} -gt 0 ] && test -x ~/.dotfiles/bin/cv ' +
    '&& command -v tmux >/dev/null && printf ''%s\n'' 0.11 $v | sort -VC && echo ok nvim $v'
  $result = wsl.exe --distribution $Distro --exec bash -lc $check 2>$null
  if ($result -match '^ok') { Write-Step "WSL ($Distro) is ready: $($result -replace '^ok ', ''), tmux and cv" }
  else { Write-Warn "WSL ($Distro) is not fully set up; run ~/.dotfiles/install.sh inside it and read its warnings" }
}

function Get-WslRelease([string]$Distro) {
  $ErrorActionPreference = 'Continue'
  # e.g. 'ubuntu 20.04'; no double quotes: Windows PowerShell 5.1 passes them unescaped
  $release = wsl.exe --distribution $Distro --exec sh -c '. /etc/os-release && echo $ID $VERSION_ID' 2>$null
  return "$release".Trim()
}

function Test-OldUbuntu([string]$Release) {
  # 22.04 and older ship tmux below 3.3 and fzf below 0.36, which this setup needs
  $id, $version = $Release -split ' ', 2
  return $id -eq 'ubuntu' -and $version -and ([version]$version -lt [version]'24.04')
}

function Install-Ubuntu2404([string]$OldDistro, [string]$Release) {
  Write-Warn "WSL's default distro $OldDistro is ${Release}: its tmux and fzf are too old for this setup."
  $answer = Read-Host 'Install Ubuntu 24.04 and make it the default? Your current distro stays installed. [Y/n]'
  if ($answer -match '^[Nn]') { return $OldDistro }
  $new = 'Ubuntu-24.04'
  $installed = (wsl.exe --list --quiet 2>$null) -replace "`0", '' | ForEach-Object { $_.Trim() }
  if ($installed -notcontains $new) {
    Write-Step 'installing Ubuntu 24.04'
    # Out-Host: whatever a function prints becomes part of its return value
    wsl.exe --install --distribution $new --no-launch | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Warn "Ubuntu 24.04 did not install (exit $LASTEXITCODE)"; return $OldDistro }
  }
  wsl.exe --set-default $new | Out-Null
  Write-Step "WSL's default distro is now $new (the old one: wsl -d $OldDistro)"
  return $new
}

function Initialize-WslUser([string]$Distro) {
  # A distro installed without its first-run setup only has root: give it your user, as default
  $ErrorActionPreference = 'Continue'
  $user = ('' + (wsl.exe --distribution $Distro --exec whoami 2>$null)).Trim()
  if ($user -and $user -ne 'root') { return }
  Write-Warn "$Distro has no Linux user yet, so one is made now."
  $suggested = $env:USERNAME.ToLower() -replace '[^a-z0-9_-]', ''
  $name = Read-Host "Linux username [$suggested]"
  if (-not $name) { $name = $suggested }
  wsl.exe --distribution $Distro --user root --exec useradd --create-home --shell /bin/bash --groups sudo $name | Out-Host
  Write-Step "choose a password for $name (sudo will ask for it)"
  # Start-Process keeps the console attached, so passwd can read what you type
  Start-Process wsl.exe -ArgumentList '--distribution', $Distro, '--user', 'root', '--exec', 'passwd', $name -NoNewWindow -Wait
  $conf = "printf '\n[user]\ndefault=$name\n' >> /etc/wsl.conf"   # no double quotes inside: see Test-WslSetup
  wsl.exe --distribution $Distro --user root --exec sh -c $conf | Out-Host
  wsl.exe --terminate $Distro | Out-Host   # the default user applies from the next start
  Write-Step "$Distro now starts as $name"
}

function Install-Wsl([bool]$NoDeps) {
  $distro = Get-WslDistro
  if (-not $distro) { Request-WslInstall; return }
  $release = Get-WslRelease $distro
  if (Test-OldUbuntu $release) { $distro = Install-Ubuntu2404 $distro $release }
  Initialize-WslUser $distro
  Write-Step "running install.sh inside WSL ($distro); it may ask for your Linux password"
  $flag = if ($NoDeps) { ' --no-deps' } else { '' }
  $script = 'set -e; if [ -d ~/.dotfiles/.git ]; then git -C ~/.dotfiles pull --ff-only; ' +
    "else git clone $RepoUrl ~/.dotfiles; fi; ~/.dotfiles/install.sh$flag"
  wsl.exe --distribution $distro --exec bash -lc $script   # --exec: no second shell re-splitting the script
  if ($LASTEXITCODE -ne 0) { Write-Warn "install.sh in WSL exited with $LASTEXITCODE; re-run it there: ~/.dotfiles/install.sh" }
  Test-WslSetup $distro
}

# --- main -------------------------------------------------------------------------------

function Install-Dotfiles {
  param([switch]$NoDeps, [switch]$SkipWsl)
  $ErrorActionPreference = 'Stop'   # scoped here so piping into iex leaves your session alone
  if ($env:DOTFILES_NO_DEPS) { $NoDeps = $true }
  if ($env:DOTFILES_SKIP_WSL) { $SkipWsl = $true }

  if (-not $NoDeps) { Write-Step 'installing tools'; Install-Packages }
  $dotfiles = Get-Dotfiles
  Write-Step 'linking configs'
  Set-Links $dotfiles
  Enable-Profile
  if (-not $NoDeps) {
    Install-Fonts
    Set-TerminalFont
    Install-Runtimes
  }
  Install-NvimPlugins $dotfiles
  if (-not $SkipWsl) { Install-Wsl $NoDeps }

  Write-Step 'done.'
  Write-Host '  next:  open a new terminal tab (Windows Terminal picks up the font and PATH)'
  Write-Host '         wsl                 zsh, tmux and dev live there'
}

if (-not $env:DOTFILES_NO_MAIN) { Install-Dotfiles @args }
