# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2025-01-08

### Added

- **Context Zones** - Status indicator based on context usage:
  - 🟢 Smart Zone (< 40%): "You are in the smart zone"
  - 🟡 Dumb Zone (40-80%): "You are in the dumb zone - Dex Horthy says so"
  - 🔴 Wrap Up Zone (> 80%): "Better to wrap up and start a new session"
- **Project name display** - Header now shows "Context Stats (project-name • session-id)"

### Changed

- **Watch mode enabled by default** - `context-stats` now runs in live monitoring mode (2s refresh)
- **Delta graph by default** - Shows "Context Growth Per Interaction" instead of both graphs
- Added `--no-watch` flag to show graphs once and exit
- Simplified installer - no script selection, auto-overwrite existing files
- Renamed graph labels to focus on context (e.g., "Context Usage Over Time")
- Cleaned up session summary - removed clutter, highlighted status

## [1.1.0] - 2025-01-08

### Changed

- **BREAKING**: Renamed package from `cc-statusline` to `cc-context-stats`
- **BREAKING**: Renamed `token-graph` CLI command to `context-stats`
- Pivoted project focus to real-time token monitoring and context tracking
- Updated tagline: "Never run out of context unexpectedly"

### Migration

If upgrading from `cc-statusline`:

```bash
pip uninstall cc-statusline
pip install cc-context-stats
```

The `claude-statusline` command still works. Replace `token-graph` with `context-stats`.

## [1.0.2] - 2025-01-08

### Fixed

- Fixed remaining context showing negative values in context-stats by using `current_used_tokens` instead of cumulative `total_input_tokens + total_output_tokens`
- Fixed ANSI escape codes not rendering properly in watch mode by using `sys.stdout.write()` instead of `print()` for cursor control sequences
- Fixed color codes in summary statistics using ColorManager instead of raw ANSI constants

## [1.0.1] - 2025-01-07

### Added

- pip/uv installable Python package (`cc-statusline` on PyPI)
- `context_window_size` field to state file for tracking remaining context
- Remaining context display in context-stats summary

### Fixed

- Restored executable permissions on script files
- Fixed stdin detection in pipe mode using INTERACTIVE flag

### Changed

- Cleaned up unused `show_io_tokens` option
- Fixed shellcheck warnings in shell scripts

## [1.0.0] - 2025-01-06

### Added

- Comprehensive test suite with Bats (Bash), pytest (Python), and Jest (Node.js)
- GitHub Actions CI/CD pipeline with multi-platform testing
- Code quality tools: ShellCheck, Ruff, ESLint, Prettier
- Pre-commit hooks for automated code quality checks
- EditorConfig for consistent formatting across editors
- CONTRIBUTING.md with development setup instructions
- Dependabot configuration for automated dependency updates
- Release automation workflow
- Full-featured status line script (`statusline-full.sh`)
- Git-aware status line script (`statusline-git.sh`)
- Minimal status line script (`statusline-minimal.sh`)
- Cross-platform Python implementation (`statusline.py`)
- Cross-platform Node.js implementation (`statusline.js`)
- Interactive installer script (`install.sh`)
- Configuration examples for Claude Code
- Autocompact (AC) buffer indicator
- Context window usage with color-coded percentages
- Git branch and uncommitted changes display

## [0.x] - Pre-release

Initial development versions with basic status line functionality.
