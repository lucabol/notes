#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CI script for the notes project — runs linting and tests.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:exitCode = 0
$script:results = @()

function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Pass($msg) { Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ❌ $msg" -ForegroundColor Red; $script:exitCode = 1 }
function Get-PythonCommand {
    foreach ($candidate in @('python', 'python3')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    throw "Python 3 is required to run the GUI tests."
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
function Test-PythonImportFromPath {
    param(
        [string]$PythonCommand,
        [string]$ModuleName,
        [string]$AdditionalPath
    )

    & $PythonCommand -c "import sys; sys.path.insert(0, r'$AdditionalPath'); import $ModuleName" 2>$null
    return $LASTEXITCODE -eq 0
}

# ── 1. Install modules ──────────────────────────────────────────────
Write-Step "Installing required modules"

foreach ($mod in @('Pester', 'PSScriptAnalyzer')) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "  Installing $mod ..."
        Install-Module -Name $mod -Force -Scope CurrentUser -SkipPublisherCheck
    } else {
        Write-Host "  $mod already installed"
    }
}

Import-Module Pester -MinimumVersion 5.0 -Force
Import-Module PSScriptAnalyzer -Force

# ── 2. PSScriptAnalyzer ─────────────────────────────────────────────
Write-Step "Running PSScriptAnalyzer on notes.ps1"

$excludeRules = @(
    'PSUseShouldProcessForStateChangingFunctions'
    'PSAvoidUsingWriteHost'
    'PSAvoidUsingInvokeExpression'
    'PSAvoidUsingConvertToSecureStringWithPlainText'
)

$analyzerResults = Invoke-ScriptAnalyzer -Path ./notes.ps1 -ExcludeRule $excludeRules -Severity Error, Warning

if ($analyzerResults) {
    $errors   = @($analyzerResults | Where-Object Severity -eq 'Error')
    $warnings = @($analyzerResults | Where-Object Severity -eq 'Warning')

    $analyzerResults | Format-Table -AutoSize RuleName, Severity, Line, Message

    if ($errors.Count -gt 0) {
        Write-Fail "PSScriptAnalyzer: $($errors.Count) error(s), $($warnings.Count) warning(s)"
        $script:results += "Lint: FAIL ($($errors.Count) errors, $($warnings.Count) warnings)"
    } else {
        Write-Pass "PSScriptAnalyzer: 0 errors, $($warnings.Count) warning(s) (warnings are non-blocking)"
        $script:results += "Lint: PASS (0 errors, $($warnings.Count) warnings)"
    }
} else {
    Write-Pass "PSScriptAnalyzer: clean"
    $script:results += "Lint: PASS (clean)"
}

# ── 3. Pester tests ─────────────────────────────────────────────────
Write-Step "Running Pester tests"

$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = './notes.tests.ps1'
$pesterConfig.Run.Exit = $false
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = './testResults.xml'
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'

$savedPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$pesterResult = Invoke-Pester -Configuration $pesterConfig
$ErrorActionPreference = $savedPref

if ($pesterResult.FailedCount -gt 0) {
    Write-Fail "Pester: $($pesterResult.FailedCount) failed out of $($pesterResult.TotalCount) tests"
    $script:results += "Tests: FAIL ($($pesterResult.FailedCount)/$($pesterResult.TotalCount) failed)"
} else {
    Write-Pass "Pester: all $($pesterResult.TotalCount) tests passed"
    $script:results += "Tests: PASS ($($pesterResult.TotalCount) tests)"
}

# ── 4. Python GUI tests ────────────────────────────────────────────────
if (Test-Path ./requirements-gui.txt) {
    Write-Step "Installing GUI Python dependencies"

    $python = Get-PythonCommand
    $platformSuffix = Get-PlatformSuffix
    $venvPath = Join-Path (Get-Location) ".venv-gui-ci-$platformSuffix"
    $venvPython = Get-VenvPythonPath -VenvPath $venvPath
    $packagePath = Join-Path (Get-Location) ".python-packages-gui-ci-$platformSuffix"
    $guiPython = $venvPython
    $guiPythonPath = $null

    $venvUsable = (Test-Path -LiteralPath $venvPython) -and (Test-PythonImport -PythonCommand $venvPython -ModuleName 'pip')
    if (-not $venvUsable) {
        & $python -m venv $venvPath
        $venvUsable = $LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $venvPython) -and (Test-PythonImport -PythonCommand $venvPython -ModuleName 'pip')
        if (-not $venvUsable) {
            Write-Host "  Falling back to a repo-local Python package directory because venv creation failed." -ForegroundColor Yellow
            $guiPython = $python
            $guiPythonPath = $packagePath
        }
    }

    if ($script:exitCode -eq 0) {
        $dependenciesInstalled = if ($null -eq $guiPythonPath) {
            Test-PythonImport -PythonCommand $guiPython -ModuleName 'PySide6'
        } else {
            Test-PythonImportFromPath -PythonCommand $guiPython -ModuleName 'PySide6' -AdditionalPath $guiPythonPath
        }

        if (-not $dependenciesInstalled) {
            if ($null -eq $guiPythonPath) {
                & $guiPython -m pip install --disable-pip-version-check -r ./requirements-gui.txt
            } else {
                New-Item -ItemType Directory -Path $guiPythonPath -Force | Out-Null
                & $guiPython -m pip install --disable-pip-version-check --target $guiPythonPath -r ./requirements-gui.txt
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Fail "GUI dependencies install failed"
                $script:results += "GUI: FAIL (dependency install failed)"
            } else {
                Write-Pass "GUI dependencies installed"
            }
        } else {
            Write-Pass "GUI dependencies already installed"
        }
    }

    if ($script:exitCode -eq 0) {
        Write-Step "Running Python GUI tests"

        $savedQtPlatform = $env:QT_QPA_PLATFORM
        $savedPythonPath = $env:PYTHONPATH
        $env:QT_QPA_PLATFORM = 'offscreen'
        if ($null -ne $guiPythonPath) {
            if ([string]::IsNullOrEmpty($savedPythonPath)) {
                $env:PYTHONPATH = $guiPythonPath
            } else {
                $env:PYTHONPATH = $guiPythonPath + [System.IO.Path]::PathSeparator + $savedPythonPath
            }
        }

        & $guiPython -m unittest discover -s ./gui_tests -v
        $guiExitCode = $LASTEXITCODE

        if ($null -eq $savedQtPlatform) {
            Remove-Item Env:QT_QPA_PLATFORM -ErrorAction SilentlyContinue
        } else {
            $env:QT_QPA_PLATFORM = $savedQtPlatform
        }

        if ($null -eq $savedPythonPath) {
            Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
        } else {
            $env:PYTHONPATH = $savedPythonPath
        }

        if ($guiExitCode -ne 0) {
            Write-Fail "GUI tests failed"
            $script:results += "GUI: FAIL (Python tests)"
        } else {
            Write-Pass "GUI tests passed"
            $script:results += "GUI: PASS (Python tests)"
        }
    }
}

# ── Summary ──────────────────────────────────────────────────────────
Write-Host "`n━━━ Summary ━━━" -ForegroundColor Yellow
$script:results | ForEach-Object { Write-Host "  $_" }
Write-Host ""

exit $script:exitCode
