---
description: Display ASCII graph of token usage for current session
argument-hint: [session_id] [--type cumulative|delta|both] [--no-color]
allowed-tools: Bash(*)
---

# Token Usage Graph

Display the token consumption history as ASCII graphs.

**IMPORTANT**: This command executes a bash script and displays its output directly. Do NOT analyze or interpret the results - simply show them to the user.

Execute the token graph script:

!`bash /Users/montimage/buildspace/luongnv89/claude-statusline/scripts/token-graph.sh $ARGUMENTS`

The output above shows the token usage visualization. No further analysis is needed.
