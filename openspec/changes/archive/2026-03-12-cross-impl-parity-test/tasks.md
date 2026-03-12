## 1. Test Infrastructure Setup

- [x] 1.1 Create `tests/bash/test_parity.bats` with bats shebang and setup/teardown functions
- [x] 1.2 Implement `setup()` that creates a temp `$HOME` directory, sets `COLUMNS=120`, and changes to a non-git temp working directory
- [x] 1.3 Implement `teardown()` that removes the temp `$HOME` and temp working directory
- [x] 1.4 Add a `strip_ansi()` helper function that removes ANSI escape codes from a string via `sed`

## 2. Stdout Parity Tests

- [x] 2.1 Add a test that loops over all `tests/fixtures/json/*.json` files, pipes each to both `python3 scripts/statusline.py` and `node scripts/statusline.js`, strips ANSI, and asserts the cleaned outputs are identical
- [x] 2.2 Add diagnostic output on failure: print fixture name, Python output, and Node.js output side-by-side

## 3. CSV State File Parity Tests

- [x] 3.1 Add a test that for each fixture: pipes to both scripts with a unique `session_id` in the JSON, reads the resulting state files, and asserts both have exactly 14 fields
- [x] 3.2 Add field-by-field comparison for CSV fields 1–13 (skipping timestamp at index 0), printing field name and both values on mismatch
- [x] 3.3 Add a timestamp tolerance check: assert field 0 differs by at most 2 seconds between the two state lines

## 4. CI Integration

- [x] 4.1 Add a `parity-test` job to `.github/workflows/ci.yml` with `needs: [python-test, node-test]`, matrix of `[ubuntu-latest, macos-latest]`, setting up Python 3.11, Node.js 20, and bats
- [x] 4.2 Add `parity-test` to the `ci-success` job's `needs` array and failure check so parity failures block merge

## 5. Validation

- [x] 5.1 Run `bats tests/bash/test_parity.bats` locally and verify all tests pass (or document known failures from existing drift)
- [x] 5.2 Verify the parity test auto-discovers new fixtures by temporarily adding a test fixture and confirming it is included
