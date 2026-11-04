# Contributing

Contributions are welcome! Please follow these guidelines.

## How to contribute

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Make your changes.
4. Run the tests: `Invoke-Pester -Path ./Tests`.
5. Run the linter: `Invoke-ScriptAnalyzer -Path . -Recurse`.
6. Commit with a clear message.
7. Open a Pull Request.

## Code style

- Follow the `.editorconfig` settings.
- Use 4-space indentation.
- Use `[CmdletBinding()]` on functions.
- Add comment-based help to new functions.
- Keep functions small and focused.

## Safety rules

- Never remove Epic Games / Fortnite files.
- Never remove source code files.
- Always support `DryRun`.
- Always create a restore point before destructive changes.
- Log all actions.

## Reporting issues

Open an issue with:
- Windows version
- PowerShell version (`$PSVersionTable`)
- Steps to reproduce
- Expected vs actual behavior
- Log file content (`%TEMP%\OtimizadorPC_log.txt`)
