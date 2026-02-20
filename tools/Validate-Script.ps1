<#
.SYNOPSIS
    Pre-commit validation script for Get-AzAIModelAvailability.
.DESCRIPTION
    Runs four checks: syntax validation, PSScriptAnalyzer linting,
    Pester tests, and version consistency.
.EXAMPLE
    .\tools\Validate-Script.ps1
.EXAMPLE
    .\tools\Validate-Script.ps1 -SkipTests
#>
[CmdletBinding()]
param(
    [switch]$SkipTests
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$mainScript = Join-Path $repoRoot 'Get-AzAIModelAvailability.ps1'
$settingsFile = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$testsDir = Join-Path $repoRoot 'tests'
$failCount = 0

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " GET-AZAIMODELAVAILABILITY VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ── Check 1: Syntax Validation ──
Write-Host "[1/4] Syntax Check" -ForegroundColor Yellow
try {
    $content = Get-Content $mainScript -Raw -ErrorAction Stop
    [scriptblock]::Create($content) | Out-Null
    Write-Host "  PASS  Script parses without syntax errors" -ForegroundColor Green
}
catch {
    Write-Host "  FAIL  Syntax error: $($_.Exception.Message)" -ForegroundColor Red
    $failCount++
}

# ── Check 2: PSScriptAnalyzer ──
Write-Host "[2/4] PSScriptAnalyzer" -ForegroundColor Yellow
$hasAnalyzer = Get-Module -ListAvailable PSScriptAnalyzer -ErrorAction SilentlyContinue
if (-not $hasAnalyzer) {
    Write-Host "  SKIP  PSScriptAnalyzer not installed" -ForegroundColor DarkYellow
}
else {
    $analyzerParams = @{ Path = $mainScript; Severity = @('Error', 'Warning') }
    if (Test-Path $settingsFile) { $analyzerParams.Settings = $settingsFile }
    $issues = Invoke-ScriptAnalyzer @analyzerParams
    if ($issues.Count -eq 0) {
        Write-Host "  PASS  No warnings or errors" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $($issues.Count) issue(s) found:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "         Line $($issue.Line): [$($issue.Severity)] $($issue.RuleName) - $($issue.Message)" -ForegroundColor Red
        }
        $failCount++
    }
}

# ── Check 3: Pester Tests ──
Write-Host "[3/4] Pester Tests" -ForegroundColor Yellow
if ($SkipTests) {
    Write-Host "  SKIP  -SkipTests specified" -ForegroundColor DarkYellow
}
else {
    $hasPester = Get-Module -ListAvailable Pester -ErrorAction SilentlyContinue |
    Where-Object { $_.Version.Major -ge 5 }
    if (-not $hasPester) {
        Write-Host "  SKIP  Pester v5+ not installed" -ForegroundColor DarkYellow
    }
    else {
        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $testsDir
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = 'None'
        $results = Invoke-Pester -Configuration $pesterConfig
        if ($results.FailedCount -eq 0) {
            Write-Host "  PASS  $($results.PassedCount) test(s) passed" -ForegroundColor Green
        }
        else {
            Write-Host "  FAIL  $($results.FailedCount) of $($results.TotalCount) test(s) failed" -ForegroundColor Red
            $failCount++
        }
    }
}

# ── Check 4: Version Consistency ──
Write-Host "[4/4] Version Consistency" -ForegroundColor Yellow
$versionMismatches = @()

if ($content -match '\$ScriptVersion\s*=\s*["'']([\d.]+)["'']') {
    $scriptVer = $matches[1]

    $readmePath = Join-Path $repoRoot 'README.md'
    if (Test-Path $readmePath) {
        try {
            $readmeContent = Get-Content $readmePath -Raw -ErrorAction Stop
            if ($readmeContent -match 'img\.shields\.io/badge/Version-([\d.]+)') {
                if ($matches[1] -ne $scriptVer) { $versionMismatches += "README.md badge: $($matches[1])" }
            }
        }
        catch { $versionMismatches += "README.md: failed to read" }
    }

    $changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
    if (Test-Path $changelogPath) {
        try {
            $changelogContent = Get-Content $changelogPath -Raw -ErrorAction Stop
            if ($changelogContent -notmatch [regex]::Escape("[$scriptVer]")) {
                $versionMismatches += "CHANGELOG.md: no [$scriptVer] entry"
            }
        }
        catch { $versionMismatches += "CHANGELOG.md: failed to read" }
    }

    if ($versionMismatches.Count -eq 0) {
        Write-Host "  PASS  All version references match v$scriptVer" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  \$ScriptVersion is v$scriptVer but mismatches found:" -ForegroundColor Red
        foreach ($m in $versionMismatches) { Write-Host "         $m" -ForegroundColor Red }
        $failCount++
    }
}
else {
    Write-Host "  SKIP  Could not find \$ScriptVersion in script" -ForegroundColor DarkYellow
}

# ── Summary ──
Write-Host "`n========================================" -ForegroundColor Cyan
if ($failCount -eq 0) {
    Write-Host " ALL CHECKS PASSED" -ForegroundColor Green
}
else {
    Write-Host " $failCount CHECK(S) FAILED" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

exit $failCount
