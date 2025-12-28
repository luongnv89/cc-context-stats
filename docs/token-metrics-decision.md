# Token Metrics Decision Log

This document summarizes the process of adding, validating, and ultimately removing token/cost metrics from the status line.

## Initial Implementation

We initially added token metrics to the status line showing:
- **Input tokens** (in) - cumulative input tokens for the session
- **Output tokens** (out) - cumulative output tokens for the session
- **Cache tokens** (cache) - cache creation + cache read tokens
- **Estimated cost** (~$X.XX) - based on API usage

Format: `[in:72k,out:83k,cache:41k]` with `~$1.25` cost prefix

## Validation Issue

When comparing the status line output with Claude Code's `/context` command, we discovered a significant discrepancy:

**Status line showed:**
```
in:153k + out:112k = 265k tokens
```

**But `/context` showed:**
```
Context window: 200k total
Messages: 92.8k tokens
Free space: 41k (20.4%)
```

The math didn't add up:
- 153k + 112k = 265k total tokens displayed
- But context window is only 200k
- And we still had 41k free space

## Root Cause

The fields `total_input_tokens` and `total_output_tokens` from Claude Code's JSON input are **cumulative API usage counters**, not current context window usage:

- They track all tokens sent/received during the entire session
- They include tokens from previous requests that may have been compacted
- They don't represent what's currently in the context window

The actual "Messages: 92.8k tokens" shown by `/context` represents what's in the context now, but this value is **not exposed** to the status line script.

## Decision

Since we cannot accurately display context token breakdown:

1. **Removed cost display** - It was an estimation based on inaccurate token counts
2. **Removed token metrics** - The in/out/cache values were misleading
3. **Kept context free space** - This is calculated from `current_usage` and is accurate

## Final Status Line Format

```
[Model] directory | branch [changes] | XXk free (XX%) [AC:45k]
```

Components:
- Model name
- Current directory
- Git branch and change count
- Free context tokens (accurate)
- Autocompact buffer size

## Lessons Learned

1. Always validate displayed metrics against authoritative sources (`/context`)
2. Cumulative session totals ≠ current context usage
3. Better to show less information than misleading information
4. The "free space" calculation using `current_usage` tokens is reliable

## Related Commits

- `refactor: Replace cost display with token metrics` - Initial attempt
- `style: Update token metrics format to [in:Xk,out:Xk,cache:Xk]` - Formatting
- `refactor: Remove misleading token metrics from statusline` - Final removal
