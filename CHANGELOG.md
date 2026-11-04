# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-04

### Added
- MIT LICENSE file.
- CHANGELOG, CONTRIBUTING, .editorconfig.
- GitHub Actions workflow for PSScriptAnalyzer lint and syntax checks.
- New optimizations: WinSxS component cleanup, prefetch cache clean, icon cache rebuild, disable Game Bar/DVR, TCP auto-tuning.
- `-Mode` parameter: `Safe` (default) or `Aggressive`.
- Automatic System Restore Point before changes.
- SSD vs HDD detection (ReTrim on SSD, defrag on HDD).
- Self-update check against GitHub raw.
- Comment-based help for all functions.
- Pester test suite (smoke tests).
- WinForms GUI (`Otimizador-GUI.ps1`).

### Changed
- Improved logging with levels.
- Clean-Temp now respects DryRun.
- Better error handling and idempotency.

### Fixed
- NullReferenceException in directory cleanup.
- Temp files deleted even in DryRun mode.

## [1.0.0] - 2026-11-04

### Added
- Initial release: interactive menu + auto mode.
- 15 optimization options.
- Protection for Epic Games / Fortnite files.
- DryRun mode.
- README and LEIA-ME.
