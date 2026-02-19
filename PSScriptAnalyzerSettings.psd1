# PSScriptAnalyzer configuration for Get-AzAIModelAvailability
# https://github.com/PowerShell/PSScriptAnalyzer
#
# This file is used by both local VS Code linting (on-save) and CI (GitHub Actions).
# Keep them in sync — if you exclude a rule here, exclude it in CI too.

@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # This is a console tool — Write-Host is intentional for color-coded output
        'PSAvoidUsingWriteHost'

        # Function names like Get-AzureEndpoints return collections —
        # plural nouns are intentional and match Azure cmdlet conventions
        'PSUseSingularNouns'

        # Some parameters are declared for future features and internal
        # function signatures — suppressing until implemented
        'PSReviewUnusedParameter'
    )

    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }
    }
}
