#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install lightweight launchers for notes.ps1 and notes-gui into a user bin directory.
#>

[CmdletBinding()]
param(
    [string]$BinDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PythonCommand {
    foreach ($candidate in @('python', 'python3')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    return $null
}

function Get-VenvPythonPath {
    param([string]$VenvPath)

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return Join-Path $VenvPath 'Scripts\python.exe'
    }

    return Join-Path $VenvPath 'bin/python'
}

function Get-PlatformSuffix {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return 'windows'
    }
    if ($IsMacOS) {
        return 'macos'
    }

    return 'linux'
}

function Test-PythonImport {
    param(
        [string]$PythonCommand,
        [string]$ModuleName
    )

    & $PythonCommand -c "import $ModuleName" 2>$null
    return $LASTEXITCODE -eq 0
}

$repoRoot = Split-Path -Parent $PSCommandPath
$notesScript = Join-Path $repoRoot 'notes.ps1'
$guiEntryPoint = Join-Path $repoRoot 'gui\main.py'
$guiRequirementsPath = Join-Path $repoRoot 'requirements-gui.txt'
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

if (Test-Path -LiteralPath $guiEntryPoint) {
    $python = Get-PythonCommand
    if ($null -eq $python) {
        Write-Warning "Python 3 was not found. Skipping notes-gui launcher installation."
    } else {
        $platformSuffix = Get-PlatformSuffix
        $guiVenvPath = Join-Path $repoRoot ".venv-gui-$platformSuffix"
        $guiPython = Get-VenvPythonPath -VenvPath $guiVenvPath
        $guiPackagePath = $null
        $guiPipExtraArgs = @()
        $useVenv = (Test-Path -LiteralPath $guiPython) -and (Test-PythonImport -PythonCommand $guiPython -ModuleName 'pip')

        if (-not $useVenv) {
            Write-Host "Creating notes-gui virtual environment..." -ForegroundColor Cyan
            & $python -m venv $guiVenvPath
            $useVenv = $LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $guiPython) -and (Test-PythonImport -PythonCommand $guiPython -ModuleName 'pip')
            if (-not $useVenv) {
                Write-Warning "Could not create a virtual environment. Falling back to installing GUI dependencies for the detected Python."
                $guiPython = $python
                if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
                    $guiPipExtraArgs = @('--user')
                    if ($platformSuffix -eq 'linux') {
                        $guiPipExtraArgs += '--break-system-packages'
                    }
                }
            }
        }

        Write-Host "Installing notes-gui dependencies..." -ForegroundColor Cyan
        & $guiPython -m pip install --disable-pip-version-check @guiPipExtraArgs -r $guiRequirementsPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install notes-gui dependencies."
        }

        $guiPsLauncherPath = Join-Path $binDir 'notes-gui.ps1'
        $escapedRepoRoot = $repoRoot.Replace("'", "''")
        $escapedGuiPython = $guiPython.Replace("'", "''")
        $guiPsLauncherContent = @"
#!/usr/bin/env pwsh
Push-Location '$escapedRepoRoot'
try {
    & '$escapedGuiPython' -m gui.main @args
    `$script:notesGuiExitCode = `$LASTEXITCODE
    if (`$null -eq `$script:notesGuiExitCode) {
        `$script:notesGuiExitCode = 0
    }
    `$global:LASTEXITCODE = `$script:notesGuiExitCode
    if ((Get-PSCallStack).Count -le 2) {
        `$host.SetShouldExit(`$script:notesGuiExitCode)
    }
} finally {
    Pop-Location
}
"@
        Set-Content -Path $guiPsLauncherPath -Value $guiPsLauncherContent -Encoding utf8
        $createdLaunchers += $guiPsLauncherPath

        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            $guiCmdLauncherPath = Join-Path $binDir 'notes-gui.cmd'
            $guiCmdLauncherContent = @"
@echo off
setlocal
pushd "$repoRoot"
"$guiPython" -m gui.main %*
set EXITCODE=%errorlevel%
popd
exit /b %EXITCODE%
"@
            Set-Content -Path $guiCmdLauncherPath -Value $guiCmdLauncherContent -Encoding ascii
            $createdLaunchers += $guiCmdLauncherPath
        } else {
            $guiShellLauncherPath = Join-Path $binDir 'notes-gui'
            $escapedShellRepoRoot = $repoRoot.Replace("'", "'""'""'")
            $escapedShellGuiPython = $guiPython.Replace("'", "'""'""'")
            $guiShellLauncherContent = @"
#!/bin/sh
cd '$escapedShellRepoRoot' || exit 1
exec '$escapedShellGuiPython' -m gui.main "`$@"
"@
            [System.IO.File]::WriteAllText(
                $guiShellLauncherPath,
                $guiShellLauncherContent.Replace("`r`n", "`n"),
                [System.Text.UTF8Encoding]::new($false)
            )
            chmod +x $guiShellLauncherPath
            $createdLaunchers += $guiShellLauncherPath
        }
    }
}

Write-Host "Created launchers:" -ForegroundColor Green
$createdLaunchers | ForEach-Object { Write-Host "  $_" }

if ((Test-Path -LiteralPath $guiEntryPoint) -and ($createdLaunchers -contains (Join-Path $binDir 'notes-gui.ps1'))) {
    Write-Host ""
    Write-Host "notes-gui is configured for this repository and ready to launch." -ForegroundColor Green
}

$pathSeparator = [System.IO.Path]::PathSeparator
$pathEntries = @($env:PATH -split [regex]::Escape([string]$pathSeparator))
if ($pathEntries -notcontains $binDir) {
    Write-Host ""
    Write-Host "Add '$binDir' to PATH to use the launcher from any shell." -ForegroundColor Yellow
}
