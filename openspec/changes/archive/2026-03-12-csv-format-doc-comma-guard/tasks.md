## 1. Documentation

- [x] 1.1 Create `docs/CSV_FORMAT.md` with field table (index 0–13, name, type, description) and at least one complete example row
- [x] 1.2 Fix `docs/ARCHITECTURE.md` line 90: replace "Each line is a JSON record with timestamp, token counts, and context metrics" with accurate CSV description and cross-reference to `docs/CSV_FORMAT.md`

## 2. Comma guard — Python

- [x] 2.1 In `src/claude_statusline/core/state.py` `to_csv_line()`, replace commas with underscores in `self.workspace_project_dir` before joining
- [x] 2.2 In `scripts/statusline.py` (standalone script), apply the same comma replacement in its CSV serialization

## 3. Comma guard — Node.js

- [x] 3.1 In `scripts/statusline.js`, replace commas with underscores in `workspaceProjectDir` before the `stateData` array join

## 4. Comma guard — Bash scripts

- [x] 4.1 In `scripts/statusline-full.sh`, sanitize `$workspace_project_dir` (replace commas with underscores) before the CSV echo line
- [x] 4.2 `statusline-mid.sh` does not exist — N/A (only `statusline-git.sh` and `statusline-minimal.sh` exist, neither writes CSV)
- [x] 4.3 `statusline-min.sh` does not exist — N/A (see 4.2)

## 5. Testing

- [x] 5.1 Add a parity test input fixture with commas in `workspace.project_dir` to `tests/bash/test_parity.bats` and verify Python/Node.js produce identical sanitized output
- [x] 5.2 Run existing parity tests to confirm no regressions
