#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install lightweight launchers for notes.ps1 into a user bin directory.
#>

[CmdletBinding()]
param(
    [string]$BinDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSCommandPath
$notesScript = Join-Path $repoRoot 'notes.ps1'
if (-not (Test-Path -LiteralPath $notesScript)) {
    throw "Could not find notes.ps1 next to install.ps1."
}

if (-not $BinDir) {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $BinDir = Join-Path $HOME 'bin'
    } else {
        $BinDir = Join-Path $HOME '.local/bin'
    }
}

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
$binDir = (Get-Item -LiteralPath $BinDir).FullName
$notesScriptPath = (Get-Item -LiteralPath $notesScript).FullName

$psLauncherPath = Join-Path $binDir 'notes.ps1'
$escapedPowerShellPath = $notesScriptPath.Replace("'", "''")
$psLauncherContent = @"
#!/usr/bin/env pwsh
& '$escapedPowerShellPath' @args
`$script:notesExitCode = `$LASTEXITCODE
if (`$null -eq `$script:notesExitCode) {
    `$script:notesExitCode = 0
}
`$global:LASTEXITCODE = `$script:notesExitCode
if ((Get-PSCallStack).Count -le 2) {
    `$host.SetShouldExit(`$script:notesExitCode)
}
"@
Set-Content -Path $psLauncherPath -Value $psLauncherContent -Encoding utf8

$createdLaunchers = @($psLauncherPath)

if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $cmdLauncherPath = Join-Path $binDir 'notes.cmd'
    $cmdLauncherContent = @"
@echo off
pwsh -NoProfile -File "$notesScriptPath" %*
exit /b %errorlevel%
"@
    Set-Content -Path $cmdLauncherPath -Value $cmdLauncherContent -Encoding ascii
    $createdLaunchers += $cmdLauncherPath
} else {
    $shellLauncherPath = Join-Path $binDir 'notes'
    $escapedShellPath = $notesScriptPath.Replace("'", "'""'""'")
    $shellLauncherContent = @"
#!/bin/sh
exec pwsh -NoProfile -File '$escapedShellPath' "`$@"
"@
    [System.IO.File]::WriteAllText(
        $shellLauncherPath,
        $shellLauncherContent.Replace("`r`n", "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    chmod +x $shellLauncherPath
    $createdLaunchers += $shellLauncherPath
}

Write-Host "Created launchers:" -ForegroundColor Green
$createdLaunchers | ForEach-Object { Write-Host "  $_" }

$pathSeparator = [System.IO.Path]::PathSeparator
$pathEntries = @($env:PATH -split [regex]::Escape([string]$pathSeparator))
if ($pathEntries -notcontains $binDir) {
    Write-Host ""
    Write-Host "Add '$binDir' to PATH to use the launcher from any shell." -ForegroundColor Yellow
}
