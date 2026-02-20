# GitHub Copilot Instructions

## Tech Stack & Architecture

- **Primary Language:** PowerShell 7+
- **Cloud Platform:** Microsoft Azure (requires Az.Accounts module)
- **Purpose:** Scans Azure regions for AI model availability via the CognitiveServices API.
- **API:** `Microsoft.CognitiveServices/locations/{region}/models` (api-version 2024-10-01)

## Key Files

- `Get-AzAIModelAvailability.ps1`: Main script
- `tests/`: Pester tests for helper and AI model functions
- `tools/Validate-Script.ps1`: Pre-commit validation script

## Build, Test, and Run

- **Run:** `.\Get-AzAIModelAvailability.ps1`
- **Test:** `Invoke-Pester ./tests -Output Detailed`
- **Validate:** `.\tools\Validate-Script.ps1`
- **Lint:** `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1`

## Code Conventions

- Use `#region`/`#endregion` for section organization
- Comments explain *why*, not *what*
- Named constants for magic numbers (in `#region Constants`)
- Every `catch` block must have at least `Write-Verbose`
- API calls use `Invoke-WithRetry` for resilience

## Related Project

- [Get-AzVMAvailability](https://github.com/zacharyluz/Get-AzVMAvailability) — VM SKU capacity scanning (shared codebase patterns)
