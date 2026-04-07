## v1.18.0 — 2026-04-07

### Features
- **Mermaid charts in report** — `context-stats report` now renders visual Mermaid charts for token usage, cost trends, and project analytics alongside the existing ASCII tables
- **Full analytics rewrite** — `generate_report` rebuilt with complete analytics matching reference format; includes richer breakdowns, improved summaries, and consistent output

### Fixes
- **Report period display** — Report header now correctly shows the date range covered by the data
- **`--since-days` filtering** — `start_time` field is now correctly used for session filtering when `--since-days` is specified
- **Mermaid x-axis labels** — Shortened x-axis labels in Mermaid charts to prevent label overlap on wide datasets

### Chore
- **Remove Node.js and Bash remnants** — Deleted all remaining Node.js and Bash script files; Python-only codebase is now complete

**Full Changelog**: https://github.com/luongnv89/cc-context-stats/compare/v1.17.0...v1.18.0
