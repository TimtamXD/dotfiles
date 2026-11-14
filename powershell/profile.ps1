# PowerShell profile (Windows PowerShell 5.1 and PowerShell 7), linked by install.ps1.
# Language runtimes come from mise's shims, which install.ps1 puts on PATH.
$env:EDITOR = 'nvim'
Set-Alias -Name vim -Value nvim
Set-Alias -Name g -Value git

if (Get-Module -ListAvailable PSReadLine) {
  Set-PSReadLineOption -EditMode Emacs -HistorySearchCursorMovesToEnd
  Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# machine-specific settings and secrets, never committed
$local = Join-Path $HOME '.profile.local.ps1'
if (Test-Path $local) { . $local }
