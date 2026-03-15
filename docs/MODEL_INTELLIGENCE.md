# Model Intelligence (MI) Metric — Implementation Plan

> Inspired by the **Michelangelo** paper: *Long Context Evaluations Beyond Haystacks via Latent Structure Queries* (arXiv:2409.12640, Google DeepMind, Sep 2024)

## Context

Users of cc-context-stats can see how much context remains, but have no indicator of **how well the model is likely performing** at the current context fill level. The Michelangelo paper demonstrates that LLM answer quality degrades predictably as context fills — with an initial sharp super-linear drop followed by linear/flat degradation. Different capabilities (reasoning, retrieval, self-awareness) degrade at different rates.

This plan introduces a **Model Intelligence (MI)** score: a [0, 1] heuristic that estimates answer quality using only data already available in the CSV state entries. It complements the existing Smart/Dumb/Wrap Up Zone indicators with a continuous, multi-dimensional score.

## Key Insights from the Paper

1. **Performance degrades with context length** — All models show significant falloff, often starting before 32K tokens. There is an initial sharp super-linear drop, followed by either flattening or continued linear degradation.

2. **Three orthogonal evaluation dimensions** (each measures different aspects):
   - **MRCR**: Understanding ordering, distinguishing similar content, reproducing context (scored via string similarity [0,1])
   - **Latent List**: Tracking a latent data structure through operations (scored via exact match + normalized error [0,1])
   - **IDK**: Knowing what the model doesn't know (scored via accuracy [0,1])

3. **Higher complexity = steeper degradation** — As task complexity increases, performance falls off faster with context length.

4. **Cross-over behavior** — Models better at short context can become worse at long context.

5. **Perplexity ≠ reasoning quality** — Low perplexity does not predict good reasoning at long contexts.

## Formula Design

### Guard Clause

If `context_window_size == 0` (old 2-field CSV entries, malformed data), return `MI = 1.0` with all sub-scores at defaults (CPS=1.0, ES=1.0, PS=0.5). This avoids division by zero and treats unknown-context entries optimistically.

### MI = 0.60 × CPS + 0.25 × ES + 0.15 × PS

Three sub-scores, each inspired by a Michelangelo evaluation dimension. Weights are **hardcoded constants** (not configurable) to minimize cross-implementation sync burden.

### 1. Context Pressure Score (CPS) — weight: 0.60

Maps to the paper's primary finding: performance degrades with context utilization.

```
u = current_used_tokens / context_window_size    (utilization ratio, 0 to 1+)
CPS = max(0, 1 - u^β)
```

Default `β = 1.5`. Configurable via `mi_curve_beta`. This creates the super-linear initial drop observed in the paper:

| Utilization (u) | CPS (β=1.5) | CPS (β=1.0, linear) | CPS (β=2.0, quadratic) |
|---|---|---|---|
| 0.0 | 1.00 | 1.00 | 1.00 |
| 0.2 | 0.91 | 0.80 | 0.96 |
| 0.4 | 0.75 | 0.60 | 0.84 |
| 0.6 | 0.54 | 0.40 | 0.64 |
| 0.8 | 0.28 | 0.20 | 0.36 |
| 1.0 | 0.00 | 0.00 | 0.00 |

**Rationale:** β=1.5 reproduces the paper's observation that performance is good early, degrades significantly past ~50%, and becomes severely impaired above ~80%. Configurable via `mi_curve_beta`.

### 2. Efficiency Score (ES) — weight: 0.25

Proxies context utilization quality (analogous to MRCR — is the model effectively re-using prior context?).

```
total_context = entry.current_used_tokens       # = current_input + cache_creation + cache_read

if total_context == 0:
    ES = 1.0                                    # No context yet
else:
    cache_hit_ratio = cache_read / total_context
    ES = 0.3 + 0.7 × cache_hit_ratio           # [0.3, 1.0]
```

**Note:** `total_context` is the same as `StateEntry.current_used_tokens` (state.py:132). Reuse the existing property in the package; compute inline in standalone scripts.

- Floor of 0.3 prevents penalizing early-session entries (no cache available yet)
- Full cache-read → ES=1.0

**Rationale:** High cache-read ratio indicates the model is successfully re-using previously cached context rather than re-processing, suggesting better context utilization.

### 3. Productivity Score (PS) — weight: 0.15

Proxies output quality (analogous to Latent List/IDK — is the model producing meaningful, actionable output?).

**Deltas are computed as consecutive entry differences** (not cumulative totals):
```
delta_lines_added  = current.lines_added  - previous.lines_added
delta_lines_removed = current.lines_removed - previous.lines_removed
delta_output_tokens = current.total_output_tokens - previous.total_output_tokens
```

```
if no previous entry OR delta_output_tokens <= 0:
    PS = 0.5                                    # Neutral
else:
    delta_lines = delta_lines_added + delta_lines_removed
    ratio = delta_lines / delta_output_tokens
    normalized = min(1.0, ratio / target)       # target: 0.2 (hardcoded)
    PS = 0.2 + 0.8 × normalized                 # [0.2, 1.0]
```

- Target: 0.2 lines/token (1 line per 5 output tokens) = perfect score, **hardcoded** (not configurable)
- Floor of 0.2 for explanation-heavy sessions (still valid work)
- Lowest weight (0.15) because it's the noisiest proxy

**Rationale:** When the model produces concrete code changes relative to token expenditure, it is likely giving focused, relevant answers. When it produces many tokens with no code changes, it may be struggling.

### Color Thresholds (hardcoded)

| MI Range | Color | Label | Interpretation |
|---|---|---|---|
| > 0.65 | Green | High Intelligence | Model is operating well |
| 0.35–0.65 | Yellow | Degraded | Context pressure affecting quality |
| < 0.35 | Red | Critical | Severely degraded, consider new session |

### Example Calculations

**Fresh session** (u=0.1, 60% cache, 150 lines/1000 tokens):
- CPS = 1 - 0.1^1.5 = 0.968
- ES = 0.3 + 0.7 × 0.6 = 0.72
- PS = 0.2 + 0.8 × min(1, 0.15/0.2) = 0.80
- **MI = 0.60×0.968 + 0.25×0.72 + 0.15×0.80 = 0.581 + 0.180 + 0.120 = 0.88**

**Mid-session** (u=0.5, 40% cache, 100 lines/1000 tokens):
- CPS = 1 - 0.5^1.5 = 0.646
- ES = 0.3 + 0.7 × 0.4 = 0.58
- PS = 0.2 + 0.8 × min(1, 0.1/0.2) = 0.60
- **MI = 0.60×0.646 + 0.25×0.58 + 0.15×0.60 = 0.388 + 0.145 + 0.090 = 0.62**

**Late session** (u=0.85, 20% cache, 50 lines/1000 tokens):
- CPS = 1 - 0.85^1.5 = 0.217
- ES = 0.3 + 0.7 × 0.2 = 0.44
- PS = 0.2 + 0.8 × min(1, 0.05/0.2) = 0.40
- **MI = 0.60×0.217 + 0.25×0.44 + 0.15×0.40 = 0.130 + 0.110 + 0.060 = 0.30**

## Implementation Steps

### Step 1: Create `src/claude_statusline/graphs/intelligence.py`

Core MI computation module:
- `IntelligenceConfig` dataclass — beta only (weights, thresholds, productivity_target are hardcoded constants)
- `IntelligenceScore` dataclass — cps, es, ps, mi, utilization (all floats)
- `calculate_context_pressure(utilization, beta) → float`
- `calculate_efficiency(entry: StateEntry) → float`
- `calculate_productivity(current: StateEntry, previous: StateEntry | None) → float` — uses **consecutive entry diffs** for delta_lines and delta_output_tokens
- `calculate_intelligence(current: StateEntry, previous: StateEntry | None, context_window_size: int, beta?) → IntelligenceScore`
  - **Guard clause:** if `context_window_size == 0`, return `IntelligenceScore(cps=1.0, es=1.0, ps=0.5, mi=1.0, utilization=0.0)`
- `get_mi_color(mi) → str` — returns "green"/"yellow"/"red" using hardcoded thresholds (0.65/0.35)
- `format_mi_score(mi) → str` — returns "0.82"

Constants (hardcoded, not configurable):
```python
MI_WEIGHT_CPS = 0.60
MI_WEIGHT_ES = 0.25
MI_WEIGHT_PS = 0.15
MI_GREEN_THRESHOLD = 0.65
MI_YELLOW_THRESHOLD = 0.35
MI_PRODUCTIVITY_TARGET = 0.2
```

### Step 2: Create `tests/python/test_intelligence.py`

Unit tests for all functions:
- **CPS**: empty/full/half context, custom beta, clamping at 0
- **CPS guard**: `context_window_size == 0` returns MI=1.0 with defaults
- **ES**: no tokens, all cache read, no cache, mixed cache
- **PS**: no previous entry, no output, high/zero/moderate productivity, capping
- **PS deltas**: verify consecutive entry diff computation (not cumulative)
- **Composite**: optimal/worst conditions, weight validation, bounds check
- **Color**: green/yellow/red thresholds, boundary values
- **Format**: two decimals, zero, one, rounding
- **Statusline integration**: `show_mi=true` + `show_delta=false` produces MI output without delta display

### Step 2b: Create `tests/fixtures/mi_test_vectors.json`

Shared test vectors for cross-implementation parity:
```json
[
  {
    "description": "Fresh session",
    "input": { "current_used": 20000, "context_window": 200000, "cache_read": 12000, "current_input": 5000, "cache_creation": 3000, "prev_lines_added": 0, "prev_lines_removed": 0, "cur_lines_added": 150, "cur_lines_removed": 10, "prev_output": 0, "cur_output": 1000, "beta": 1.5 },
    "expected": { "cps": 0.968, "es": 0.72, "ps": 0.84, "mi": 0.887 }
  }
]
```

5-6 vectors covering: fresh session, mid-session, late session, no previous entry, context_window=0, no cache. Both Python and Node.js test suites read this file and assert results within ±0.01 tolerance.

### Step 3: Modify `src/claude_statusline/core/config.py`

Add to `Config` dataclass (only 2 new fields):
- `show_mi: bool = True`
- `mi_curve_beta: float = 1.5`

All other MI parameters (weights, thresholds, productivity_target) are **hardcoded constants** in `intelligence.py`, not configurable. This minimizes cross-implementation sync burden (2 config branches vs 8).

Add parsing in `_read_config()`:
- `show_mi`: boolean, same pattern as existing keys (`value_lower != "false"`)
- `mi_curve_beta`: float, inline `try/except` — `try: self.mi_curve_beta = float(raw_value) except ValueError: pass`

Add MI section to `_create_default()` config template:
```ini
# Model Intelligence (MI) score display
show_mi=true

# MI degradation curve shape (higher = steeper initial drop)
# mi_curve_beta=1.5
```

Update `to_dict()` with both new fields.

### Step 4: Modify `src/claude_statusline/cli/statusline.py`

**Key change:** Decouple state file reads from `show_delta`. Currently, the previous entry is only read inside `if config.show_delta:`. With MI, the previous entry must be read whenever `show_mi` OR `show_delta` is enabled.

Restructure the state file logic:
```python
# Read previous entry if needed for delta OR MI
if config.show_delta or config.show_mi:
    state_file = StateFile(session_id)
    prev_entry = state_file.read_last_entry()
    # ... build current entry, append if changed ...

    if config.show_delta:
        # ... existing delta_info logic ...

    if config.show_mi:
        from claude_statusline.graphs.intelligence import calculate_intelligence, get_mi_color, format_mi_score
        mi_score = calculate_intelligence(entry, prev_entry, total_size, config.mi_curve_beta)
        mi_color_name = get_mi_color(mi_score.mi)
        mi_color = getattr(colors, mi_color_name)
        mi_info = f" {mi_color}MI:{format_mi_score(mi_score.mi)}{colors.reset}"
```

Add `mi_info` to the output parts list (between `delta_info` and `ac_info`). Color-code using `get_mi_color()`.

### Step 5: Modify `src/claude_statusline/graphs/renderer.py`

**Two changes:**

**5a.** Add optional `label_fn: Callable[[int], str] | None = None` parameter to `render_timeseries()`. When provided, use it instead of `format_tokens()` for Y-axis labels. This allows the MI graph to display `0.62` instead of `620` when data is scaled ×1000. Default behavior (existing graphs) is unchanged.

**5b.** In `render_summary()` (~line 318, after zone indicator), add MI score display:
```
  Model Intelligence:  0.62  (Context pressure is degrading answer quality)
    CPS: 0.54  ES: 0.72  PS: 0.60
```
Accepts an optional `IntelligenceScore` parameter.

### Step 6: Modify `src/claude_statusline/cli/context_stats.py`

- Add `"mi"` to `--type` choices
- In `render_once()`: compute MI scores for each entry pair and render as timeseries graph (scale ×1000 for integer renderer)
- Use `label_fn=lambda v: f"{v/1000:.2f}"` when calling `render_timeseries()` for the MI graph
- Include MI in `"all"` graph type
- Pass MI score to `render_summary()`

### Step 7: Modify `scripts/statusline.py` (standalone)

Add a single self-contained `compute_mi()` function (not 4 separate functions) that takes raw values and returns `(mi, cps, es, ps)`. This reduces the sync surface from 4 functions to 1.

```python
def compute_mi(used_tokens, context_window_size, cache_read, total_context,
               delta_lines, delta_output, beta=1.5):
    """Compute Model Intelligence score. Returns (mi, cps, es, ps)."""
    ...
```

Add `show_mi` and `mi_curve_beta` config parsing (2 keys, matching the package). Add `MI:X.XX` to output. Decouple state file read from `show_delta` (same restructuring as Step 4).

### Step 8: Modify `scripts/statusline.js` (standalone Node.js)

Port MI formula as a single `computeMI()` function (same signature as Python). Add `show_mi` and `mi_curve_beta` config parsing. Add `MI:X.XX` to output. Decouple state file read from `showDelta`.

```javascript
function computeMI(usedTokens, contextWindowSize, cacheRead, totalContext,
                   deltaLines, deltaOutput, beta = 1.5) {
    // Returns { mi, cps, es, ps }
}
```

### Step 9: Add Node.js tests and shared test vectors

- Create `tests/fixtures/mi_test_vectors.json` with 5-6 test vectors
- Port core MI formula tests to `tests/node/intelligence.test.js`, reading from shared vectors
- Update `tests/python/test_intelligence.py` to also read from shared vectors
- Ensures cross-implementation parity within ±0.01 tolerance

## Critical Files

| File | Action | Description |
|---|---|---|
| `src/claude_statusline/graphs/intelligence.py` | **Create** | Core MI computation module (hardcoded constants + configurable beta) |
| `tests/python/test_intelligence.py` | **Create** | Unit tests for MI module (incl. guard clause, integration tests) |
| `tests/fixtures/mi_test_vectors.json` | **Create** | Shared test vectors for cross-implementation parity |
| `src/claude_statusline/core/config.py` | **Modify** | Add `show_mi` (bool) and `mi_curve_beta` (float) only |
| `src/claude_statusline/cli/statusline.py` | **Modify** | Add MI score; decouple state read from `show_delta` |
| `src/claude_statusline/cli/context_stats.py` | **Modify** | Add `--type mi` graph option |
| `src/claude_statusline/graphs/renderer.py` | **Modify** | Add `label_fn` param to `render_timeseries()`; add MI to summary |
| `scripts/statusline.py` | **Modify** | Single `compute_mi()` function; decouple state read |
| `scripts/statusline.js` | **Modify** | Single `computeMI()` function; decouple state read |
| `tests/node/intelligence.test.js` | **Create** | Node.js MI tests using shared vectors |

## Existing Utilities to Reuse

- `StateEntry.current_used_tokens` property (`core/state.py:132`) — already computes `current_input_tokens + cache_creation + cache_read` (used for both CPS utilization and ES total_context)
- `ColorManager` (`core/colors.py`) — for MI color coding
- `fit_to_width()` (`formatters/layout.py`) — for statusline width management
- `Config.load()` pattern (`core/config.py`) — extended with 2 new fields
- `GraphRenderer.render_timeseries()` (`graphs/renderer.py`) — for MI graph (extended with `label_fn` parameter)

**Not used**: `format_tokens()` — MI uses its own `f"{mi:.2f}"` format. `calculate_deltas()` — MI computes its own consecutive entry diffs internally.

## Configuration Options

Only 2 config keys are exposed (weights, thresholds, and productivity target are hardcoded constants to minimize cross-implementation sync burden):

```ini
# Model Intelligence (MI) score display
# Shows a heuristic quality score based on context utilization
show_mi=true

# MI degradation curve shape (higher = steeper initial drop)
# Based on Michelangelo paper's observed performance degradation
# mi_curve_beta=1.5
```

Hardcoded constants (in `intelligence.py`, `compute_mi()`, and `computeMI()`):
- Weights: CPS=0.60, ES=0.25, PS=0.15
- Thresholds: green > 0.65, yellow > 0.35, red below
- Productivity target: 0.2 lines/token

## Display Integration

### Statusline output

```text
[Opus] myproject | main [3] | 75k free (37.5%) [+2,500] MI:0.62 [AC:45k] abc123
```

### Context Stats CLI summary

```text
Session Summary
────────────────────────────────────────────────
  Context Remaining:  75,000/200,000 (37%)
  >>> DUMB ZONE <<<   (You are in the dumb zone - Dex Horthy says so)
  Model Intelligence: 0.62  (Context pressure is degrading answer quality)
    CPS: 0.54  ES: 0.72  PS: 0.60
```

### Context Stats MI graph (`--type mi`)

ASCII timeseries graph of MI score over time, showing the degradation trajectory.

## Verification

1. **Unit tests**: `pytest tests/python/test_intelligence.py -v`
2. **All Python tests**: `source venv/bin/activate && pytest tests/python/ -v`
3. **Node.js tests**: `npm test` (includes `intelligence.test.js` with shared vectors)
4. **Cross-implementation parity**: Both Python and Node.js test suites read `tests/fixtures/mi_test_vectors.json` and assert results within ±0.01
5. **Manual statusline test**: Pipe JSON to statusline and verify `MI:X.XX` appears
6. **Manual statusline test (decoupled)**: Set `show_mi=true` + `show_delta=false` and verify MI appears without delta
7. **Manual context-stats test**: `context-stats --type mi --no-watch` — verify MI graph renders with decimal Y-axis labels

## Known Limitations

1. **Productivity Score is noisy for non-coding sessions** — Research/planning sessions have low PS even with high-quality answers. Mitigation: PS has lowest weight (0.15) and floor of 0.2.

2. **Cache hit ratio reflects API behavior, not reasoning quality** — Cache management is infrastructure, not model intelligence. Mitigation: ES weight is moderate (0.25) and presented as a heuristic proxy.

3. **Degradation curve is not calibrated to specific models** — The paper found different curves per model family. Mitigation: `mi_curve_beta` is configurable.

4. **Integer graph renderer** — MI scores (floats [0,1]) are scaled to [0, 1000] for the integer-based renderer, with Y-axis labels formatted as decimals via `label_fn`.

5. **MI adds file I/O when show_delta=false** — When `show_mi=true` and `show_delta=false`, the statusline reads the previous entry for PS calculation. Users who need minimal I/O can set `show_mi=false`.

## Review Decisions Log

Decisions made during engineering review (2026-03-14):

| # | Decision | Resolution |
|---|---|---|
| 1 | PS delta definition | Consecutive entry diffs (not cumulative totals) |
| 2 | CPS division by zero | Guard clause: return MI=1.0 when context_window_size=0 |
| 3 | MI vs show_delta coupling | Decoupled — MI reads prev entry independently |
| 4 | Config surface area | Only `show_mi` + `mi_curve_beta` (hardcode the rest) |
| 5 | MI formula DRY | Single `compute_mi()` / `computeMI()` in standalone scripts |
| 6 | Module location | Keep in `graphs/` next to `statistics.py` |
| 7 | Float config parsing | Inline try/except for `mi_curve_beta` |
| 8 | MI graph Y-axis | Add `label_fn` parameter to `render_timeseries()` |
| 9 | Cross-impl parity | Shared `tests/fixtures/mi_test_vectors.json` |

## TODOs (deferred)

- **Shared test vectors**: Create `tests/fixtures/mi_test_vectors.json` with 5-6 vectors for cross-implementation parity (agreed during review, to be built during implementation)
- **MI trend indicators**: Show `MI:0.62↓` or `MI:0.82↑` in statusline based on comparison with previous MI score (deferred — adds cross-impl sync burden)
- **Per-model beta calibration**: Map known model IDs to empirically tuned beta values (deferred — requires empirical data we don't have yet)
