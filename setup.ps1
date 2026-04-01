#!/usr/bin/env pwsh
# Wrapper to run setup.sh via Git Bash on Windows
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (-not (Test-Path $gitBash)) {
    Write-Host "Git Bash not found at $gitBash" -ForegroundColor Red
    Write-Host "Install Git for Windows: https://git-scm.com/download/win"
    exit 1
}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& $gitBash "$scriptDir/setup.sh" @args
