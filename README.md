# Get-AzAIModelAvailability

A PowerShell tool for checking Azure AI model availability across regions — find where your models can deploy.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)

## Disclosure & Disclaimer

The author is a Microsoft employee; however, this is a **personal open-source project**. It is **not** an official Microsoft product, nor is it endorsed, sponsored, or supported by Microsoft.

- **No warranty**: Provided "as-is" under the [MIT License](LICENSE).
- **No official support**: For Azure platform issues, use [Azure Support](https://azure.microsoft.com/support/).
- **No confidential information**: This tool uses only publicly documented Azure APIs.
- **Trademarks**: "Microsoft" and "Azure" are trademarks of Microsoft Corporation.

## Overview

Get-AzAIModelAvailability helps you identify which Azure regions have AI models available for deployment. It scans regions and provides detailed insights into model providers, lifecycle status, deployment types, and capacity.

Azure AI model availability varies significantly by region — for example, **Anthropic models are only available in eastus2**, and **OpenAI has 42 models in eastus2 vs 17 in westeurope**. This tool surfaces those differences in seconds.

## See Also

**Looking for VM SKU capacity scanning?** See [Get-AzVMAvailability](https://github.com/zacharyluz/Get-AzVMAvailability) — the companion tool for checking VM SKU availability, quota, and pricing across regions.

## Features

- **Multi-Region Scanning** — Scan up to 5 regions in ~3 seconds
- **12+ AI Providers** — OpenAI, Meta, Anthropic, Microsoft, DeepSeek, Mistral AI, Cohere, xAI, and more
- **Provider Filtering** — Focus on specific providers (e.g., `'OpenAI','Anthropic'`)
- **Model Filtering** — Wildcard support (e.g., `'gpt-4*'`, `'*embed*'`)
- **Lifecycle Filtering** — GenerallyAvailable, Stable, Preview, Deprecated
- **Deployment Types** — Standard, GlobalStandard, ProvisionedManaged, DataZone, Batch
- **Multi-Region Matrix** — Color-coded comparison view
- **Interactive Drill-Down** — Explore providers and individual models
- **Export Options** — CSV and styled XLSX

## Quick Comparison

| Task                            | Azure Portal        | This Script      |
| ------------------------------- | ------------------- | ---------------- |
| Check models across 5 regions   | ~10 minutes         | ~3 seconds       |
| Compare providers across regions | Multiple blades     | Single matrix    |
| Filter to specific models       | Manual browsing     | Wildcard filter  |
| Check lifecycle status          | Per-model lookup    | Aggregated view  |
| Export results                  | Manual copy/paste   | One command      |

## Requirements

- **PowerShell 7.0+** (recommended)
- **Azure PowerShell Module**: `Az.Accounts`
- **Optional**: `ImportExcel` module for styled XLSX export

## Installation

```powershell
# Clone the repository
git clone https://github.com/zacharyluz/Get-AzAIModelAvailability.git
cd Get-AzAIModelAvailability

# Install required Azure module (if needed)
Install-Module -Name Az.Accounts -Scope CurrentUser

# Optional: Install ImportExcel for styled exports
Install-Module -Name ImportExcel -Scope CurrentUser
```

## Quick Start

```powershell
# Interactive mode — prompts for region selection
.\Get-AzAIModelAvailability.ps1

# Automated scan — top US regions
.\Get-AzAIModelAvailability.ps1 -RegionPreset USMajor -NoPrompt

# With auto-export
.\Get-AzAIModelAvailability.ps1 -Region "eastus","eastus2" -AutoExport
```

## Usage Examples

### Scan All Providers Across Regions
```powershell
.\Get-AzAIModelAvailability.ps1 -Region "eastus","eastus2","westeurope" -NoPrompt
```

### Filter to Specific Providers
```powershell
.\Get-AzAIModelAvailability.ps1 `
    -ProviderFilter "OpenAI","Anthropic","Meta" `
    -RegionPreset USMajor -NoPrompt
```

### Find GPT-4 Models with Drill-Down
```powershell
.\Get-AzAIModelAvailability.ps1 `
    -ModelFilter "gpt-4*" `
    -Region "eastus2" `
    -EnableDrillDown
```

### Export Only GA Models
```powershell
.\Get-AzAIModelAvailability.ps1 `
    -LifecycleFilter "GenerallyAvailable" `
    -RegionPreset Europe `
    -AutoExport -OutputFormat XLSX
```

### Check Azure Government
```powershell
.\Get-AzAIModelAvailability.ps1 -RegionPreset USGov -NoPrompt
```

## Parameters

| Parameter         | Type     | Description                                                           |
| ----------------- | -------- | --------------------------------------------------------------------- |
| `-SubscriptionId` | String   | Azure subscription ID (default: current context)                      |
| `-Region`         | String[] | Azure region code(s) (e.g., 'eastus', 'westus2')                     |
| `-RegionPreset`   | String   | Predefined region set (USMajor, Europe, etc.)                         |
| `-ProviderFilter` | String[] | Filter to specific providers (e.g., 'OpenAI', 'Meta')                |
| `-ModelFilter`    | String[] | Filter by model name with wildcards (e.g., 'gpt-4*')                 |
| `-LifecycleFilter`| String[] | Filter by lifecycle (GA, Stable, Preview, Deprecated)                 |
| `-DeploymentType` | String[] | Filter by deploy type (Standard, GlobalStandard, etc.)                |
| `-ExportPath`     | String   | Directory for export files                                            |
| `-AutoExport`     | Switch   | Export without prompting                                              |
| `-EnableDrillDown`| Switch   | Interactive provider/model exploration                                |
| `-NoPrompt`       | Switch   | Skip interactive prompts                                              |
| `-OutputFormat`   | String   | 'Auto', 'CSV', or 'XLSX'                                             |
| `-UseAsciiIcons`  | Switch   | Force ASCII instead of Unicode icons                                  |
| `-Environment`    | String   | Azure cloud override (AzureCloud, AzureUSGovernment, etc.)            |
| `-MaxRetries`     | Int      | Retry attempts for transient errors (default: 3)                      |

## Region Presets

| Preset          | Regions                                                             |
| --------------- | ------------------------------------------------------------------- |
| `USEastWest`    | eastus, eastus2, westus, westus2                                    |
| `USMajor`       | eastus, eastus2, centralus, westus, westus2                         |
| `Europe`        | westeurope, northeurope, uksouth, francecentral, germanywestcentral |
| `AsiaPacific`   | eastasia, southeastasia, japaneast, australiaeast, koreacentral     |
| `Global`        | eastus, westeurope, southeastasia, australiaeast, brazilsouth       |
| `USGov`         | usgovvirginia, usgovtexas, usgovarizona (auto-sets environment)     |
| `China`         | chinaeast, chinanorth, chinaeast2, chinanorth2 (auto-sets env)      |

## Output

### Per-Region Provider Summary
```
Provider               Models   Unique    GA  Stable   Prevw Deploy Types              Top Model
-----------------------------------------------------------------------------------------------------------------
Anthropic                   6        6     0       0       6 GlobalStandard            claude-sonnet-4-5
OpenAI                     42       33    28       0      14 DataZoneBatch,Standard... o4-mini
Meta                       19        7     0      19       0 GlobalStandard,...         Llama-3.3-70B
```

### Multi-Region Matrix
```
Provider         | eastus         eastus2        westeurope
----------------------------------------------------------------
Anthropic        | -              6 models       -
OpenAI           | 20 models      42 models      17 models
Meta             | 19 models      19 models      19 models
```

### Drill-Down Detail
```
--- OpenAI (42 models in eastus2) ---
  Model                               Version         Lifecycle          Max Capacity    Deploy Types
  gpt-4.1                             2025-04-14      GenerallyAvailable 3               Standard,GlobalStandard
  gpt-4o                              2024-08-06      GenerallyAvailable 3               Standard,GlobalStandard,Prov...
  claude-sonnet-4-5                   20250929        Preview            3               GlobalStandard
```

## Supported Cloud Environments

| Cloud            | Supported |
| ---------------- | --------- |
| Azure Commercial | ✅         |
| Azure Government | ✅         |
| Azure China      | ✅         |

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Author

**Zachary Luz** — Personal project (not an official Microsoft product)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
