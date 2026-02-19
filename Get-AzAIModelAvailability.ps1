<#
.SYNOPSIS
    Get-AzAIModelAvailability - Scan Azure AI model availability across regions.

.DESCRIPTION
    Scans Azure regions for AI model availability using the Microsoft.CognitiveServices API.
    Provides a comprehensive view of:
    - All AI model providers available in each region (OpenAI, Meta, Anthropic, etc.)
    - Model counts, versions, and lifecycle status per provider
    - Deployment type availability (Standard, GlobalStandard, ProvisionedManaged, etc.)
    - Multi-region comparison matrix
    - Interactive drill-down by provider and model with capacity details
    - CSV/XLSX export

    Companion tool to Get-AzVMAvailability for VM SKU capacity scanning.

.PARAMETER SubscriptionId
    Azure subscription ID to scan. If not provided, uses current Az context.

.PARAMETER Region
    One or more Azure region codes to scan (e.g., 'eastus', 'westus2').
    If not provided, prompts interactively or uses defaults with -NoPrompt.

.PARAMETER RegionPreset
    Predefined region set for common scenarios.
    Sovereign cloud presets (USGov, China) auto-set the environment.

.PARAMETER ProviderFilter
    Filter to specific AI model providers (e.g., 'OpenAI', 'Meta', 'Anthropic').

.PARAMETER ModelFilter
    Filter to specific model names. Supports wildcards (e.g., 'gpt-4*', '*embed*').

.PARAMETER LifecycleFilter
    Filter by lifecycle status: GenerallyAvailable, Stable, Preview, Deprecated.
    Default: excludes Deprecated models.

.PARAMETER DeploymentType
    Filter by deployment type (e.g., 'Standard', 'GlobalStandard', 'ProvisionedManaged').

.PARAMETER ExportPath
    Directory path for CSV/XLSX export.

.PARAMETER AutoExport
    Automatically export results without prompting.

.PARAMETER EnableDrillDown
    Enable interactive drill-down to explore providers and individual models.

.PARAMETER NoPrompt
    Skip all interactive prompts. Uses defaults or provided parameters.

.PARAMETER OutputFormat
    Export format: 'Auto' (detects XLSX capability), 'CSV', or 'XLSX'.

.PARAMETER UseAsciiIcons
    Force ASCII icons instead of Unicode ✓ ⚠ ✗.

.PARAMETER Environment
    Azure cloud environment override. Auto-detects from Az context if not specified.
    Options: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud

.PARAMETER MaxRetries
    Max retry attempts for transient API errors (429, 503, timeouts). Default: 3.

.NOTES
    Name:           Get-AzAIModelAvailability
    Author:         Zachary Luz
    Created:        2026-02-19
    Version:        1.0.0
    License:        MIT
    Repository:     https://github.com/zacharyluz/Get-AzAIModelAvailability

    Requirements:   Az.Accounts module
                    PowerShell 7+ (recommended)

    See also:       Get-AzVMAvailability — VM SKU capacity scanning
                    https://github.com/zacharyluz/Get-AzVMAvailability

.EXAMPLE
    .\Get-AzAIModelAvailability.ps1
    Run interactively with prompts for region selection.

.EXAMPLE
    .\Get-AzAIModelAvailability.ps1 -Region "eastus","eastus2","westeurope" -NoPrompt
    Scan three regions showing all AI model providers.

.EXAMPLE
    .\Get-AzAIModelAvailability.ps1 -ProviderFilter "OpenAI","Anthropic" -RegionPreset USMajor -NoPrompt
    Check OpenAI and Anthropic model availability across top US regions.

.EXAMPLE
    .\Get-AzAIModelAvailability.ps1 -ModelFilter "gpt-4*" -Region "eastus2" -EnableDrillDown
    Drill down into GPT-4 family models in eastus2 with version and capacity details.

.EXAMPLE
    .\Get-AzAIModelAvailability.ps1 -LifecycleFilter "GenerallyAvailable" -RegionPreset Europe -AutoExport
    Export only GA models across European regions to XLSX.

.EXAMPLE
    .\Get-AzAIModelAvailability.ps1 -RegionPreset USGov -NoPrompt
    Scan Azure Government regions (auto-sets environment).

.LINK
    https://github.com/zacharyluz/Get-AzAIModelAvailability
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure subscription ID to scan")]
    [Alias("SubId", "Subscription")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "Azure region(s) to scan")]
    [Alias("Location")]
    [string[]]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Predefined region sets for common scenarios")]
    [ValidateSet("USEastWest", "USCentral", "USMajor", "Europe", "AsiaPacific", "Global", "USGov", "China", "ASR-EastWest", "ASR-CentralUS")]
    [string]$RegionPreset,

    [Parameter(Mandatory = $false, HelpMessage = "Filter to specific AI model providers")]
    [string[]]$ProviderFilter,

    [Parameter(Mandatory = $false, HelpMessage = "Filter models by name (supports wildcards, e.g., 'gpt-4*')")]
    [string[]]$ModelFilter,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by lifecycle status")]
    [ValidateSet("GenerallyAvailable", "Stable", "Preview", "Deprecated")]
    [string[]]$LifecycleFilter,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by deployment type")]
    [string[]]$DeploymentType,

    [Parameter(Mandatory = $false, HelpMessage = "Directory path for export")]
    [string]$ExportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically export results")]
    [switch]$AutoExport,

    [Parameter(Mandatory = $false, HelpMessage = "Enable interactive provider/model drill-down")]
    [switch]$EnableDrillDown,

    [Parameter(Mandatory = $false, HelpMessage = "Skip all interactive prompts")]
    [switch]$NoPrompt,

    [Parameter(Mandatory = $false, HelpMessage = "Export format: Auto, CSV, or XLSX")]
    [ValidateSet("Auto", "CSV", "XLSX")]
    [string]$OutputFormat = "Auto",

    [Parameter(Mandatory = $false, HelpMessage = "Force ASCII icons instead of Unicode")]
    [switch]$UseAsciiIcons,

    [Parameter(Mandatory = $false, HelpMessage = "Azure cloud environment (default: auto-detect)")]
    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureChinaCloud", "AzureGermanCloud")]
    [string]$Environment,

    [Parameter(Mandatory = $false, HelpMessage = "Max retry attempts for transient API errors")]
    [ValidateRange(0, 10)]
    [int]$MaxRetries = 3
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

#region Configuration
$ScriptVersion = "1.0.0"

#region Constants
$OutputWidth = 113
$OutputWidthMin = 100
$OutputWidthMax = 150
$DefaultRegions = @('eastus', 'eastus2', 'westus2')
$MaxRegions = 5
#endregion Constants

$Regions = $Region

# Region Presets — same sets as Get-AzVMAvailability for familiarity
$RegionPresets = @{
    'USEastWest'    = @('eastus', 'eastus2', 'westus', 'westus2')
    'USCentral'     = @('centralus', 'northcentralus', 'southcentralus', 'westcentralus')
    'USMajor'       = @('eastus', 'eastus2', 'centralus', 'westus', 'westus2')
    'Europe'        = @('westeurope', 'northeurope', 'uksouth', 'francecentral', 'germanywestcentral')
    'AsiaPacific'   = @('eastasia', 'southeastasia', 'japaneast', 'australiaeast', 'koreacentral')
    'Global'        = @('eastus', 'westeurope', 'southeastasia', 'australiaeast', 'brazilsouth')
    'USGov'         = @('usgovvirginia', 'usgovtexas', 'usgovarizona')
    'China'         = @('chinaeast', 'chinanorth', 'chinaeast2', 'chinanorth2')
    'ASR-EastWest'  = @('eastus', 'westus2')
    'ASR-CentralUS' = @('centralus', 'eastus2')
}

if ($RegionPreset) {
    $Regions = $RegionPresets[$RegionPreset]
    Write-Verbose "Using region preset '$RegionPreset': $($Regions -join ', ')"

    # Auto-set environment for sovereign cloud presets
    if ($RegionPreset -eq 'USGov' -and -not $Environment) {
        $script:TargetEnvironment = 'AzureUSGovernment'
        Write-Verbose "Auto-setting environment to AzureUSGovernment for USGov preset"
    }
    elseif ($RegionPreset -eq 'China' -and -not $Environment) {
        $script:TargetEnvironment = 'AzureChinaCloud'
        Write-Verbose "Auto-setting environment to AzureChinaCloud for China preset"
    }
}

if ($Environment) {
    $script:TargetEnvironment = $Environment
}

# Default lifecycle filter: exclude Deprecated unless user explicitly includes them
if (-not $LifecycleFilter) {
    $LifecycleFilter = @('GenerallyAvailable', 'Stable', 'Preview')
}

# Detect execution environment
$isCloudShell = $env:CLOUD_SHELL -eq "true" -or (Test-Path "/home/system" -ErrorAction SilentlyContinue)
$defaultExportPath = if ($isCloudShell) { "/home/system" } else { "C:\Temp\AzAIModelAvailability" }

# Auto-detect Unicode support for status icons
$supportsUnicode = -not $UseAsciiIcons -and (
    $Host.UI.SupportsVirtualTerminal -or
    $env:WT_SESSION -or
    $env:TERM_PROGRAM -eq 'vscode' -or
    ($env:TERM -and $env:TERM -match 'xterm|256color')
)

$Icons = if ($supportsUnicode) {
    @{
        Check   = '✓'
        Warning = '⚠'
        Error   = '✗'
    }
}
else {
    @{
        Check   = '[+]'
        Warning = '[!]'
        Error   = '[-]'
    }
}

if ($AutoExport -and -not $ExportPath) {
    $ExportPath = $defaultExportPath
}

#endregion Configuration
#region Helper Functions

function Get-SafeString {
    <#
    .SYNOPSIS
        Safely converts a value to string, unwrapping arrays from parallel execution.
    #>
    param([object]$Value)
    if ($null -eq $Value) { return '' }
    while ($Value -is [array] -and $Value.Count -gt 0) {
        $Value = $Value[0]
    }
    if ($null -eq $Value) { return '' }
    return "$Value"
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic for transient Azure API errors.
    .DESCRIPTION
        Retries on HTTP 429 (Too Many Requests), 503 (Service Unavailable),
        network timeouts, and WebExceptions. Uses exponential backoff with jitter.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [int]$MaxRetries = 3,

        [string]$OperationName = 'API call'
    )

    $attempt = 0
    while ($true) {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            $ex = $_.Exception
            $isRetryable = $false
            $waitSeconds = [math]::Pow(2, $attempt)

            $statusCode = if ($ex.Response) { $ex.Response.StatusCode.value__ } else { $null }
            if ($statusCode -eq 429 -or $ex.Message -match '429|Too Many Requests') {
                $isRetryable = $true
                if ($ex.Response -and $ex.Response.Headers) {
                    $retryAfter = $ex.Response.Headers['Retry-After']
                    if ($retryAfter -and [int]::TryParse($retryAfter, [ref]$null)) {
                        $waitSeconds = [int]$retryAfter
                    }
                }
            }
            elseif ($statusCode -eq 503 -or $ex.Message -match '503|Service Unavailable') {
                $isRetryable = $true
            }
            elseif ($ex -is [System.Net.WebException] -or
                $ex -is [System.Net.Http.HttpRequestException] -or
                $ex.InnerException -is [System.Net.WebException] -or
                $ex.InnerException -is [System.Net.Http.HttpRequestException] -or
                $ex.Message -match 'timed?\s*out|connection.*reset|connection.*refused') {
                $isRetryable = $true
            }

            if (-not $isRetryable -or $attempt -ge $MaxRetries) {
                throw
            }

            $jitter = Get-Random -Minimum 0 -Maximum ([math]::Max(1, [int]($waitSeconds * 0.25)))
            $waitSeconds += $jitter

            Write-Verbose "$OperationName failed (attempt $attempt/$MaxRetries): $($ex.Message). Retrying in ${waitSeconds}s..."
            Start-Sleep -Seconds $waitSeconds
        }
    }
}

function Get-GeoGroup {
    <#
    .SYNOPSIS
        Maps an Azure region code to its geographic group for display grouping.
    #>
    param([string]$LocationCode)
    $code = $LocationCode.ToLower()
    switch -regex ($code) {
        '^(eastus|eastus2|westus|westus2|westus3|centralus|northcentralus|southcentralus|westcentralus)' { return 'Americas-US' }
        '^(usgov|usdod|usnat|ussec)' { return 'Americas-USGov' }
        '^canada' { return 'Americas-Canada' }
        '^(brazil|chile|mexico)' { return 'Americas-LatAm' }
        '^(westeurope|northeurope|france|germany|switzerland|uksouth|ukwest|swedencentral|norwayeast|norwaywest|poland|italy|spain)' { return 'Europe' }
        '^(eastasia|southeastasia|japaneast|japanwest|koreacentral|koreasouth)' { return 'Asia-Pacific' }
        '^(centralindia|southindia|westindia|jioindia)' { return 'India' }
        '^(uae|qatar|israel|saudi)' { return 'Middle East' }
        '^(southafrica|egypt|kenya)' { return 'Africa' }
        '^(australia|newzealand)' { return 'Australia' }
        default { return 'Other' }
    }
}

function Get-AzureEndpoints {
    <#
    .SYNOPSIS
        Resolves Azure endpoints based on the current cloud environment.
    .DESCRIPTION
        Auto-detects the Azure environment (Commercial, Government, China, etc.)
        and returns the appropriate API endpoints. Supports sovereign clouds.
    #>
    param(
        [object]$AzEnvironment,
        [string]$EnvironmentName
    )

    if ($EnvironmentName) {
        try {
            $AzEnvironment = Get-AzEnvironment -Name $EnvironmentName -ErrorAction Stop
            if (-not $AzEnvironment) {
                Write-Warning "Environment '$EnvironmentName' not found. Using default Commercial cloud."
            }
            else {
                Write-Verbose "Using explicit environment: $EnvironmentName"
            }
        }
        catch {
            Write-Warning "Could not get environment '$EnvironmentName': $_. Using default Commercial cloud."
            $AzEnvironment = $null
        }
    }

    if (-not $AzEnvironment) {
        try {
            $context = Get-AzContext -ErrorAction Stop
            if ($context) {
                $AzEnvironment = $context.Environment
            }
        }
        catch {
            Write-Warning "Could not get Azure context. Using default Commercial cloud endpoints."
        }
    }

    if (-not $AzEnvironment) {
        return @{
            EnvironmentName    = 'AzureCloud'
            ResourceManagerUrl = 'https://management.azure.com'
        }
    }

    $armUrl = $AzEnvironment.ResourceManagerUrl
    if (-not $armUrl) { $armUrl = 'https://management.azure.com' }
    $armUrl = $armUrl.TrimEnd('/')

    $endpoints = @{
        EnvironmentName    = $AzEnvironment.Name
        ResourceManagerUrl = $armUrl
    }

    Write-Verbose "Azure Environment: $($endpoints.EnvironmentName)"
    Write-Verbose "Resource Manager URL: $($endpoints.ResourceManagerUrl)"

    return $endpoints
}

function Test-ImportExcelModule {
    try {
        $module = Get-Module ImportExcel -ListAvailable -ErrorAction SilentlyContinue
        if ($module) {
            Import-Module ImportExcel -ErrorAction Stop -WarningAction SilentlyContinue
            return $true
        }
        return $false
    }
    catch { return $false }
}

#endregion Helper Functions
#region AI Model Functions

function Test-ModelMatchesFilter {
    <#
    .SYNOPSIS
        Tests if a model name matches any pattern in the filter list (wildcard support).
    #>
    param(
        [string]$ModelName,
        [string[]]$FilterPatterns
    )
    if (-not $FilterPatterns -or $FilterPatterns.Count -eq 0) { return $true }
    foreach ($pattern in $FilterPatterns) {
        $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
        if ($ModelName -match $regexPattern) { return $true }
    }
    return $false
}

function Get-AIModelData {
    <#
    .SYNOPSIS
        Queries AI model availability for a region using the CognitiveServices API.
    .DESCRIPTION
        Calls /providers/Microsoft.CognitiveServices/locations/{region}/models
        and applies provider, model, lifecycle, and deployment type filters.
        Deduplicates results (API returns entries per kind: OpenAI vs AIServices).
    #>
    param(
        [Parameter(Mandatory)][string]$Region,
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$AccessToken,
        [string]$ArmUrl = "https://management.azure.com",
        [string[]]$ProviderFilter,
        [string[]]$ModelFilter,
        [string[]]$LifecycleFilter,
        [string[]]$DeployTypeFilter,
        [int]$MaxRetries = 3
    )

    $uri = "$ArmUrl/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Region/models?api-version=2024-10-01"
    $allModels = @()
    $nextLink = $uri

    while ($nextLink) {
        $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName "AI Models API ($Region)" -ScriptBlock {
            Invoke-RestMethod -Uri $nextLink -Headers @{ Authorization = "Bearer $AccessToken" } -Method GET -TimeoutSec 60
        }
        if ($response.value) {
            $allModels += $response.value
        }
        $nextLink = $response.nextLink
    }

    # Deduplicate: API returns separate entries per 'kind' (OpenAI vs AIServices)
    $deduped = @{}
    foreach ($m in $allModels) {
        $key = "$($m.model.format)|$($m.model.name)|$($m.model.version)"
        if (-not $deduped.ContainsKey($key) -or @($m.model.skus).Count -gt @($deduped[$key].model.skus).Count) {
            $deduped[$key] = $m
        }
    }
    $allModels = @($deduped.Values)

    # Apply filters
    $filtered = $allModels | Where-Object {
        $model = $_
        $pass = $true

        if ($ProviderFilter -and $ProviderFilter.Count -gt 0) {
            if ($model.model.format -notin $ProviderFilter) { $pass = $false }
        }

        if ($pass -and $ModelFilter) {
            $pass = Test-ModelMatchesFilter -ModelName $model.model.name -FilterPatterns $ModelFilter
        }

        if ($pass -and $LifecycleFilter -and $LifecycleFilter.Count -gt 0) {
            if ($model.model.lifecycleStatus -notin $LifecycleFilter) { $pass = $false }
        }

        if ($pass -and $DeployTypeFilter -and $DeployTypeFilter.Count -gt 0) {
            $modelSkuNames = @($model.model.skus | ForEach-Object { $_.name })
            $hasMatch = $false
            foreach ($dt in $DeployTypeFilter) {
                if ($dt -in $modelSkuNames) { $hasMatch = $true; break }
            }
            if (-not $hasMatch) { $pass = $false }
        }

        $pass
    }

    return $filtered
}

function Get-AIModelCapacity {
    <#
    .SYNOPSIS
        Gets capacity details for a specific AI model in a region.
    #>
    param(
        [Parameter(Mandatory)][string]$Region,
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$ModelFormat,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelVersion,
        [string]$ArmUrl = "https://management.azure.com",
        [int]$MaxRetries = 3
    )

    $uri = "$ArmUrl/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Region/modelCapacities?api-version=2024-10-01&modelFormat=$ModelFormat&modelName=$ModelName&modelVersion=$ModelVersion"

    try {
        $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName "Model Capacity ($Region/$ModelName)" -ScriptBlock {
            Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $AccessToken" } -Method GET -TimeoutSec 60
        }
        return $response.value
    }
    catch {
        Write-Verbose "Failed to get capacity for $ModelName in $Region`: $($_.Exception.Message)"
        return @()
    }
}

function Group-AIModelsByProvider {
    <#
    .SYNOPSIS
        Groups raw AI model data into provider-level summaries for display.
    #>
    param(
        [Parameter(Mandatory)][array]$Models,
        [Parameter(Mandatory)][string]$Region
    )

    $grouped = $Models | Group-Object { $_.model.format }

    $summaries = foreach ($group in ($grouped | Sort-Object Name)) {
        $models = $group.Group
        $lifecycles = $models | Group-Object { $_.model.lifecycleStatus }
        $gaCount = ($lifecycles | Where-Object Name -eq 'GenerallyAvailable').Count
        $stableCount = ($lifecycles | Where-Object Name -eq 'Stable').Count
        $previewCount = ($lifecycles | Where-Object Name -eq 'Preview').Count

        $deployTypes = @($models | ForEach-Object { $_.model.skus } | ForEach-Object { $_.name } | Sort-Object -Unique)
        $topModel = ($models | Sort-Object { @($_.model.skus).Count } -Descending | Select-Object -First 1).model.name
        $uniqueNames = @($models | ForEach-Object { $_.model.name } | Sort-Object -Unique)

        [PSCustomObject]@{
            Provider    = $group.Name
            Region      = $Region
            TotalModels = $models.Count
            UniqueNames = $uniqueNames.Count
            GA          = [int]$gaCount
            Stable      = [int]$stableCount
            Preview     = [int]$previewCount
            DeployTypes = ($deployTypes -join ',')
            TopModel    = $topModel
            Models      = $models
        }
    }

    return $summaries
}

#endregion AI Model Functions
#region Initialize Azure Endpoints
$script:AzureEndpoints = Get-AzureEndpoints -EnvironmentName $script:TargetEnvironment

#endregion Initialize Azure Endpoints
#region Interactive Prompts

if (-not $SubscriptionId) {
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if ($ctx -and $ctx.Subscription.Id) {
        $SubscriptionId = $ctx.Subscription.Id
        Write-Host "Using current subscription: $($ctx.Subscription.Name)" -ForegroundColor DarkGray
    }
    else {
        Write-Host "ERROR: No Azure context found. Run Connect-AzAccount first." -ForegroundColor Red
        return
    }
}

if (-not $Regions) {
    if ($NoPrompt) {
        $Regions = $DefaultRegions
        Write-Host "Using default regions: $($Regions -join ', ')" -ForegroundColor DarkGray
    }
    else {
        Write-Host "`nAvailable region presets:" -ForegroundColor Yellow
        $presetNames = @($RegionPresets.Keys | Sort-Object)
        for ($i = 0; $i -lt $presetNames.Count; $i++) {
            $pName = $presetNames[$i]
            Write-Host "  $($i + 1). $pName ($($RegionPresets[$pName] -join ', '))" -ForegroundColor White
        }
        Write-Host "`nSelect preset (1-$($presetNames.Count)), or type region codes (comma-separated): " -ForegroundColor Yellow -NoNewline
        $regionInput = Read-Host

        if ($regionInput -match '^\d+$' -and [int]$regionInput -ge 1 -and [int]$regionInput -le $presetNames.Count) {
            $selectedPreset = $presetNames[[int]$regionInput - 1]
            $Regions = $RegionPresets[$selectedPreset]
            Write-Host "Using preset '$selectedPreset': $($Regions -join ', ')" -ForegroundColor Green
        }
        elseif (-not [string]::IsNullOrWhiteSpace($regionInput)) {
            $Regions = @($regionInput -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
        }
        else {
            $Regions = $DefaultRegions
            Write-Host "Using default regions: $($Regions -join ', ')" -ForegroundColor DarkGray
        }
    }
}

# Enforce region limit
if ($Regions.Count -gt $MaxRegions) {
    Write-Warning "Maximum $MaxRegions regions supported. Truncating to first $MaxRegions."
    $Regions = $Regions | Select-Object -First $MaxRegions
}

#endregion Interactive Prompts
#region Data Collection

Write-Host "`n" -NoNewline
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
Write-Host "GET-AZAIMODELAVAILABILITY v$ScriptVersion" -ForegroundColor Magenta
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Cyan
Write-Host "Regions: $($Regions -join ', ')" -ForegroundColor Cyan

$filterInfo = @()
if ($ProviderFilter) { $filterInfo += "Providers: $($ProviderFilter -join ', ')" }
if ($ModelFilter) { $filterInfo += "Models: $($ModelFilter -join ', ')" }
if ($LifecycleFilter) { $filterInfo += "Lifecycle: $($LifecycleFilter -join ', ')" }
if ($DeploymentType) { $filterInfo += "Deploy: $($DeploymentType -join ', ')" }
if ($filterInfo.Count -gt 0) {
    Write-Host ($filterInfo -join ' | ') -ForegroundColor Yellow
}
else {
    Write-Host "Filters: None (showing all non-deprecated models)" -ForegroundColor DarkGray
}
Write-Host "Icons: $(if ($supportsUnicode) { 'Unicode' } else { 'ASCII' }) | Cloud: $($script:AzureEndpoints.EnvironmentName)" -ForegroundColor DarkGray
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray

# Get access token
$tokenObj = Get-AzAccessToken -ResourceUrl "$($script:AzureEndpoints.ResourceManagerUrl)" -AsSecureString
$accessToken = [System.Net.NetworkCredential]::new('', $tokenObj.Token).Password
$armUrl = $script:AzureEndpoints.ResourceManagerUrl

$scanStart = Get-Date
$allRegionData = @{}

Write-Host "`nScanning AI models in $($Regions.Count) region(s)..." -ForegroundColor Yellow

foreach ($regionCode in $Regions) {
    try {
        $models = Get-AIModelData `
            -Region $regionCode `
            -SubscriptionId $SubscriptionId `
            -AccessToken $accessToken `
            -ArmUrl $armUrl `
            -ProviderFilter $ProviderFilter `
            -ModelFilter $ModelFilter `
            -LifecycleFilter $LifecycleFilter `
            -DeployTypeFilter $DeploymentType `
            -MaxRetries $MaxRetries

        $allRegionData[$regionCode] = $models
        Write-Host "  $($Icons.Check) $regionCode`: $($models.Count) models" -ForegroundColor Green
    }
    catch {
        Write-Host "  $($Icons.Error) $regionCode`: $($_.Exception.Message)" -ForegroundColor Red
        $allRegionData[$regionCode] = @()
    }
}

$scanElapsed = (Get-Date) - $scanStart
Write-Host "Scan complete in $([math]::Round($scanElapsed.TotalSeconds, 1))s" -ForegroundColor Green

#endregion Data Collection
#region Process Results

$regionSummaries = @{}
foreach ($regionCode in $Regions) {
    $models = $allRegionData[$regionCode]
    if ($models -and $models.Count -gt 0) {
        $regionSummaries[$regionCode] = Group-AIModelsByProvider -Models $models -Region $regionCode
    }
    else {
        $regionSummaries[$regionCode] = @()
    }
}

$allProviders = @($regionSummaries.Values | ForEach-Object { $_ } | ForEach-Object { $_.Provider } | Sort-Object -Unique)

#endregion Process Results
#region Per-Region Summary Tables

foreach ($regionCode in $Regions) {
    Write-Host ""
    Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
    Write-Host "REGION: $regionCode" -ForegroundColor Cyan
    Write-Host ("=" * $OutputWidth) -ForegroundColor Gray

    $summaries = $regionSummaries[$regionCode]
    if (-not $summaries -or $summaries.Count -eq 0) {
        Write-Host "No AI models found matching filters." -ForegroundColor DarkGray
        continue
    }

    $headerFmt = "{0,-20} {1,8} {2,8} {3,5} {4,7} {5,7} {6,-25} {7,-20}"
    Write-Host ($headerFmt -f "Provider", "Models", "Unique", "GA", "Stable", "Prevw", "Deploy Types", "Top Model") -ForegroundColor White
    Write-Host ("-" * $OutputWidth) -ForegroundColor DarkGray

    foreach ($s in $summaries) {
        $deployDisplay = if ($s.DeployTypes.Length -gt 25) { $s.DeployTypes.Substring(0, 22) + "..." } else { $s.DeployTypes }
        $topDisplay = if ($s.TopModel.Length -gt 20) { $s.TopModel.Substring(0, 17) + "..." } else { $s.TopModel }

        $rowColor = if ($s.TotalModels -ge 20) { 'Green' } elseif ($s.TotalModels -ge 5) { 'White' } else { 'DarkGray' }
        Write-Host ($headerFmt -f $s.Provider, $s.TotalModels, $s.UniqueNames, $s.GA, $s.Stable, $s.Preview, $deployDisplay, $topDisplay) -ForegroundColor $rowColor
    }

    $totalModels = ($summaries | Measure-Object -Property TotalModels -Sum).Sum
    Write-Host ("-" * $OutputWidth) -ForegroundColor DarkGray
    Write-Host "Total: $totalModels models from $($summaries.Count) providers" -ForegroundColor DarkGray
}

#endregion Per-Region Summary Tables
#region Multi-Region Matrix

Write-Host ""
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
Write-Host "MULTI-REGION AI MODEL MATRIX" -ForegroundColor Green
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
Write-Host ""
Write-Host "Shows total model count per provider per region. Green = available in all scanned regions." -ForegroundColor DarkGray
Write-Host ""

$colWidth = 14
$providerCol = 16
$matrixHeader = ("{0,-$providerCol}" -f "Provider") + " | "
$matrixHeader += ($Regions | ForEach-Object { "{0,-$colWidth}" -f $_ }) -join " "
Write-Host $matrixHeader -ForegroundColor White
Write-Host ("-" * ($providerCol + 3 + ($Regions.Count * ($colWidth + 1)))) -ForegroundColor DarkGray

foreach ($provider in $allProviders) {
    $row = "{0,-$providerCol}" -f $provider
    $row += " | "
    foreach ($regionCode in $Regions) {
        $regionSummary = $regionSummaries[$regionCode] | Where-Object { $_.Provider -eq $provider }
        $cell = if ($regionSummary) { "$($regionSummary.TotalModels) models" } else { "-" }
        $row += "{0,-$colWidth} " -f $cell
    }

    $regionPresence = ($Regions | Where-Object { ($regionSummaries[$_] | Where-Object { $_.Provider -eq $provider }) }).Count
    $rowColor = if ($regionPresence -eq $Regions.Count) { 'Green' }
    elseif ($regionPresence -gt 0) { 'Yellow' }
    else { 'DarkGray' }
    Write-Host $row -ForegroundColor $rowColor
}

Write-Host ""
Write-Host "HOW TO READ THIS:" -ForegroundColor DarkGray
Write-Host "  Green row  = Provider available in all scanned regions" -ForegroundColor Green
Write-Host "  Yellow row = Provider only in some regions (check which)" -ForegroundColor Yellow
Write-Host "  '-'        = Provider has no models in that region" -ForegroundColor DarkGray

#endregion Multi-Region Matrix
#region Drill-Down

if ($EnableDrillDown) {
    Write-Host ""
    Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
    Write-Host "AI MODEL DRILL-DOWN" -ForegroundColor Green
    Write-Host ("=" * $OutputWidth) -ForegroundColor Gray

    # Select region for drill-down
    $drillRegion = $null
    if ($NoPrompt) {
        $drillRegion = $Regions[0]
    }
    else {
        Write-Host "`nSelect region for drill-down:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Regions.Count; $i++) {
            $rc = $Regions[$i]
            $mc = if ($allRegionData[$rc]) { $allRegionData[$rc].Count } else { 0 }
            Write-Host "  $($i + 1). $rc ($mc models)" -ForegroundColor White
        }
        Write-Host "Selection (1-$($Regions.Count), or Enter to skip): " -ForegroundColor Yellow -NoNewline
        $regionChoice = Read-Host
        if ($regionChoice -match '^\d+$' -and [int]$regionChoice -ge 1 -and [int]$regionChoice -le $Regions.Count) {
            $drillRegion = $Regions[[int]$regionChoice - 1]
        }
    }

    if ($drillRegion) {
        $drillModels = $allRegionData[$drillRegion]
        $drillSummaries = $regionSummaries[$drillRegion]

        # Select provider(s)
        $drillProviders = @()
        if ($NoPrompt) {
            $drillProviders = @($drillSummaries | ForEach-Object { $_.Provider })
        }
        else {
            Write-Host "`nProviders in $drillRegion`:" -ForegroundColor Yellow
            $provList = @($drillSummaries | ForEach-Object { $_.Provider })
            for ($i = 0; $i -lt $provList.Count; $i++) {
                $ps = $drillSummaries | Where-Object { $_.Provider -eq $provList[$i] }
                Write-Host "  $($i + 1). $($provList[$i]) ($($ps.TotalModels) models)" -ForegroundColor White
            }
            Write-Host "Select providers (comma-separated, 'all', or Enter to skip): " -ForegroundColor Yellow -NoNewline
            $provChoice = Read-Host
            if ($provChoice -match '^all$') {
                $drillProviders = $provList
            }
            elseif (-not [string]::IsNullOrWhiteSpace($provChoice)) {
                $indices = $provChoice -split ',' | ForEach-Object { $_.Trim() }
                foreach ($idx in $indices) {
                    if ($idx -match '^\d+$' -and [int]$idx -ge 1 -and [int]$idx -le $provList.Count) {
                        $drillProviders += $provList[[int]$idx - 1]
                    }
                }
            }
        }

        foreach ($provName in $drillProviders) {
            $provModels = $drillModels | Where-Object { $_.model.format -eq $provName }
            Write-Host "`n--- $provName ($($provModels.Count) models in $drillRegion) ---" -ForegroundColor Cyan

            $byName = $provModels | Group-Object { $_.model.name } | Sort-Object Name

            $detailFmt = "  {0,-35} {1,-15} {2,-18} {3,-15} {4,-30}"
            Write-Host ($detailFmt -f "Model", "Version", "Lifecycle", "Max Capacity", "Deploy Types") -ForegroundColor White
            Write-Host ("  " + ("-" * ($OutputWidth - 2))) -ForegroundColor DarkGray

            foreach ($nameGroup in $byName) {
                foreach ($m in ($nameGroup.Group | Sort-Object { $_.model.version })) {
                    $lifecycle = $m.model.lifecycleStatus
                    $maxCap = if ($m.model.maxCapacity) { $m.model.maxCapacity.ToString() } else { "-" }
                    $deploys = @($m.model.skus | ForEach-Object { $_.name }) -join ','
                    if ($deploys.Length -gt 30) { $deploys = $deploys.Substring(0, 27) + "..." }

                    $lifecycleColor = switch ($lifecycle) {
                        'GenerallyAvailable' { 'Green' }
                        'Stable' { 'White' }
                        'Preview' { 'Yellow' }
                        'Deprecated' { 'DarkGray' }
                        default { 'Gray' }
                    }

                    Write-Host ($detailFmt -f $m.model.name, $m.model.version, $lifecycle, $maxCap, $deploys) -ForegroundColor $lifecycleColor
                }
            }
        }
    }
}

#endregion Drill-Down
#region Completion

$totalElapsed = (Get-Date) - $scanStart
$totalModelsScanned = ($allRegionData.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum

Write-Host ""
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
Write-Host "AI MODEL SCAN COMPLETE" -ForegroundColor Green
Write-Host "Models: $totalModelsScanned across $($Regions.Count) region(s) | Providers: $($allProviders.Count) | Time: $([math]::Round($totalElapsed.TotalSeconds, 1))s" -ForegroundColor DarkGray
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ("=" * $OutputWidth) -ForegroundColor Gray

#endregion Completion
#region Export

if ($ExportPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $useXLSX = ($OutputFormat -eq 'XLSX') -or ($OutputFormat -eq 'Auto' -and (Test-ImportExcelModule))

    Write-Host "`nEXPORTING..." -ForegroundColor Cyan

    # Build flat export rows
    $exportRows = @()
    foreach ($regionCode in $Regions) {
        foreach ($m in $allRegionData[$regionCode]) {
            $deploys = @($m.model.skus | ForEach-Object { $_.name }) -join ', '
            $deprecation = if ($m.model.deprecation.inference) { $m.model.deprecation.inference } else { "-" }
            $maxCap = if ($m.model.maxCapacity) { $m.model.maxCapacity } else { "-" }
            $capabilities = @()
            if ($m.model.capabilities) {
                $m.model.capabilities.PSObject.Properties | ForEach-Object {
                    if ($_.Value -eq 'true') { $capabilities += $_.Name }
                }
            }
            $exportRows += [PSCustomObject]@{
                Region       = $regionCode
                Provider     = $m.model.format
                Model        = $m.model.name
                Version      = $m.model.version
                Lifecycle    = $m.model.lifecycleStatus
                MaxCapacity  = $maxCap
                DeployTypes  = $deploys
                Deprecation  = $deprecation
                Capabilities = ($capabilities -join ', ')
            }
        }
    }

    if (-not (Test-Path $ExportPath)) {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }

    if ($useXLSX) {
        $xlsxFile = Join-Path $ExportPath "AzAIModels-$timestamp.xlsx"

        # Summary sheet — provider-level rollup
        $summaryRows = @()
        foreach ($regionCode in $Regions) {
            foreach ($s in $regionSummaries[$regionCode]) {
                $summaryRows += [PSCustomObject]@{
                    Region      = $regionCode
                    Provider    = $s.Provider
                    TotalModels = $s.TotalModels
                    UniqueNames = $s.UniqueNames
                    GA          = $s.GA
                    Stable      = $s.Stable
                    Preview     = $s.Preview
                    DeployTypes = $s.DeployTypes
                    TopModel    = $s.TopModel
                }
            }
        }
        $summaryRows | Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -FreezeTopRow -AutoFilter
        $exportRows | Export-Excel -Path $xlsxFile -WorksheetName "Details" -AutoSize -FreezeTopRow -AutoFilter -Append

        Write-Host "  $($Icons.Check) Exported: $xlsxFile" -ForegroundColor Green
        Write-Host "    Summary: $($summaryRows.Count) rows | Details: $($exportRows.Count) rows" -ForegroundColor DarkGray
    }
    else {
        $csvFile = Join-Path $ExportPath "AzAIModels-$timestamp.csv"
        $exportRows | Export-Csv -Path $csvFile -NoTypeInformation
        Write-Host "  $($Icons.Check) Exported: $csvFile ($($exportRows.Count) rows)" -ForegroundColor Green
    }
}

#endregion Export
