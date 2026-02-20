# Contributing to Get-AzAIModelAvailability

Thank you for your interest in contributing! Here are some guidelines.

## How to Contribute

1. **Fork** the repository
2. **Create a feature branch** from `main` (`git checkout -b feature/my-feature`)
3. **Make your changes** following the conventions below
4. **Run validation** before committing: `.\tools\Validate-Script.ps1`
5. **Commit** with a meaningful message (conventional commits style)
6. **Push** your branch and open a **Pull Request**

## Code Conventions

- **PowerShell 7+** — Use modern PowerShell syntax
- **Comments** — Explain *why*, not *what*. No instructional comments.
- **Constants** — Use named constants for magic numbers
- **Error handling** — Every `catch` block must have at least `Write-Verbose`
- **Sections** — Use `#region`/`#endregion` for code organization

## Testing

- Run tests: `Invoke-Pester ./tests -Output Detailed`
- All new functions should have Pester tests
- Tests must pass before merging

## Commit Messages

Use [conventional commits](https://www.conventionalcommits.org/):

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `test:` — Adding or updating tests
- `chore:` — Maintenance tasks

## Important

- **Do not** include subscription IDs, tenant IDs, or confidential information in issues or PRs
- **Always update** `CHANGELOG.md` when making functional changes
