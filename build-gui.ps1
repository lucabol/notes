#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build the notes-gui desktop app with PyInstaller.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PythonCommand {
    foreach ($candidate in @('python', 'python3')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    throw "Python 3 is required to build notes-gui."
}

$repoRoot = Split-Path -Parent $PSCommandPath
Set-Location $repoRoot

$python = Get-PythonCommand
$venvPath = Join-Path $repoRoot '.venv-gui-build'

if (-not (Test-Path $venvPath)) {
    & $python -m venv $venvPath
}

$venvPython = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Join-Path $venvPath 'Scripts\python.exe'
} else {
    Join-Path $venvPath 'bin/python'
}

& $venvPython -m pip install --disable-pip-version-check -r .\requirements-gui.txt pyinstaller
& $venvPython -m PyInstaller --noconfirm --name notes-gui --windowed .\gui\main.py

Write-Host "notes-gui build completed under .\dist\notes-gui" -ForegroundColor Green
