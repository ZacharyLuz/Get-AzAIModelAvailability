# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-19

### Added
- **Initial release** — Azure AI model availability scanner
- **Multi-region scanning** — Scan up to 5 regions via CognitiveServices Models API
- **12+ AI providers** — OpenAI, Meta, Anthropic, Microsoft, DeepSeek, Mistral AI, Cohere, xAI, MoonshotAI, Alibaba, Black Forest Labs, OpenAI-OSS, Core42
- **Provider filtering** — `-ProviderFilter` to focus on specific vendors
- **Model filtering** — `-ModelFilter` with wildcard support (e.g., `gpt-4*`, `*embed*`)
- **Lifecycle filtering** — `-LifecycleFilter` for GenerallyAvailable, Stable, Preview, Deprecated
- **Deployment type filtering** — `-DeploymentType` for Standard, GlobalStandard, ProvisionedManaged, etc.
- **Per-region summary tables** — Provider model counts, lifecycle breakdown, deployment types, top model
- **Multi-region comparison matrix** — Color-coded provider availability across regions
- **Interactive drill-down** — Explore providers → individual models with versions and capacity
- **CSV/XLSX export** — Summary and Details sheets with auto-filter
- **Region presets** — USMajor, Europe, AsiaPacific, Global, USGov, China, and more
- **Sovereign cloud support** — Azure Government and Azure China with auto-detection
- **Retry resilience** — Exponential backoff with jitter for 429/503/timeout errors
- **API deduplication** — Handles duplicate entries per `kind` (OpenAI vs AIServices)
- **Unicode/ASCII auto-detection** — Graceful fallback for narrow terminals
- **Cloud Shell compatible** — Works in Azure Cloud Shell

### Infrastructure (ported from Get-AzVMAvailability)
- `Invoke-WithRetry` — Retry logic with exponential backoff
- `Get-SafeString` — Safe string unwrapping for parallel execution
- `Get-AzureEndpoints` — Sovereign cloud endpoint resolution
- `Get-GeoGroup` — Region geography mapping
- `Test-ImportExcelModule` — XLSX export detection
- Region presets, icon detection, output formatting patterns

### Developer Tooling
- `.editorconfig` — Consistent formatting (UTF-8 BOM, CRLF, 4-space indent)
- `PSScriptAnalyzerSettings.psd1` — Shared lint config
- `tools/Validate-Script.ps1` — Pre-commit validation (syntax + lint + tests + version check)
- GitHub Actions CI — PSScriptAnalyzer + Pester on push/PR
- Pester tests — Helper functions + AI model functions
