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

# ── Summary ──────────────────────────────────────────────────────────
Write-Host "`n━━━ Summary ━━━" -ForegroundColor Yellow
$script:results | ForEach-Object { Write-Host "  $_" }
Write-Host ""

exit $script:exitCode
