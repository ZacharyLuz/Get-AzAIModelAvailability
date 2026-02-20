# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.0.x   | ✅         |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** open a public issue
2. **Email**: Contact the author directly via GitHub profile
3. **Include**: Description of the vulnerability, steps to reproduce, and potential impact

## Scope

This tool:
- Queries only **public Azure management APIs** (`Microsoft.CognitiveServices`)
- Reads subscription metadata (subscription IDs, regions, model availability)
- Writes results **locally only** (console output, CSV/XLSX files)
- Does **not** transmit data to third parties
- Does **not** store or cache credentials

## Best Practices

- Review exported files (CSV/XLSX) before sharing — they contain subscription and region information
- Use least-privilege access when running the tool
- Keep your Azure PowerShell modules updated
