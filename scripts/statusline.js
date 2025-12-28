#!/usr/bin/env node
/**
 * Node.js status line script for Claude Code
 * Usage: Copy to ~/.claude/statusline.js and make executable
 *
 * Autocompact Configuration:
 * The AC (autocompact) setting must be manually synced with Claude Code.
 * Create/edit ~/.claude/statusline.conf and set:
 *   autocompact=true   (when autocompact is enabled in Claude Code - default)
 *   autocompact=false  (when you disable autocompact via /config in Claude Code)
 *
 * When AC is enabled, 22.5% of context window is reserved for autocompact buffer.
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

// ANSI Colors
const BLUE = '\x1b[0;34m';
const MAGENTA = '\x1b[0;35m';
const CYAN = '\x1b[0;36m';
const GREEN = '\x1b[0;32m';
const YELLOW = '\x1b[0;33m';
const RED = '\x1b[0;31m';
const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

function getGitInfo(projectDir) {
    const gitDir = path.join(projectDir, '.git');
    if (!fs.existsSync(gitDir) || !fs.statSync(gitDir).isDirectory()) {
        return '';
    }

    try {
        // Get branch name (skip optional locks for performance)
        const branch = execSync('git --no-optional-locks rev-parse --abbrev-ref HEAD', {
            cwd: projectDir,
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe']
        }).trim();

        if (!branch) return '';

        // Count changes
        const status = execSync('git --no-optional-locks status --porcelain', {
            cwd: projectDir,
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe']
        });
        const changes = status.split('\n').filter(l => l.trim()).length;

        if (changes > 0) {
            return ` | ${MAGENTA}${branch}${RESET} ${CYAN}[${changes}]${RESET}`;
        }
        return ` | ${MAGENTA}${branch}${RESET}`;
    } catch {
        return '';
    }
}

function readAutocompactSetting() {
    const configPath = path.join(os.homedir(), '.claude', 'statusline.conf');
    if (!fs.existsSync(configPath)) {
        return true; // Default: enabled
    }

    try {
        const content = fs.readFileSync(configPath, 'utf8');
        for (const line of content.split('\n')) {
            const trimmed = line.trim();
            if (trimmed.startsWith('#') || !trimmed.includes('=')) {
                continue;
            }
            const [key, value] = trimmed.split('=', 2);
            if (key.trim() === 'autocompact') {
                return value.trim().toLowerCase() !== 'false';
            }
        }
    } catch {
        // Ignore errors
    }
    return true; // Default: enabled
}

let input = '';

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);

process.stdin.on('end', () => {
    let data;
    try {
        data = JSON.parse(input);
    } catch {
        console.log('[Claude] ~');
        return;
    }

    // Extract data
    const cwd = data.workspace?.current_dir || '~';
    const projectDir = data.workspace?.project_dir || cwd;
    const model = data.model?.display_name || 'Claude';
    const dirName = path.basename(cwd) || '~';

    // Git info
    const gitInfo = getGitInfo(projectDir);

    // Autocompact setting - read from config file
    const autocompactEnabled = readAutocompactSetting();

    // Context window calculation
    let contextInfo = '';
    let acInfo = '';
    const totalSize = data.context_window?.context_window_size || 0;
    const currentUsage = data.context_window?.current_usage;

    if (totalSize > 0 && currentUsage) {
        // Get tokens from current_usage (includes cache)
        const inputTokens = currentUsage.input_tokens || 0;
        const cacheCreation = currentUsage.cache_creation_input_tokens || 0;
        const cacheRead = currentUsage.cache_read_input_tokens || 0;

        // Total used from current request
        const usedTokens = inputTokens + cacheCreation + cacheRead;

        // Calculate autocompact buffer (22.5% of context window = 45k for 200k)
        const autocompactBuffer = Math.floor(totalSize * 0.225);

        // Free tokens calculation depends on autocompact setting
        let freeTokens;
        if (autocompactEnabled) {
            // When AC enabled: subtract buffer to show actual usable space
            freeTokens = totalSize - usedTokens - autocompactBuffer;
            acInfo = ` ${DIM}[AC]${RESET}`;
        } else {
            // When AC disabled: show full free space
            freeTokens = totalSize - usedTokens;
            acInfo = ` ${DIM}[AC:off]${RESET}`;
        }

        if (freeTokens < 0) {
            freeTokens = 0;
        }

        // Calculate percentage with one decimal (relative to total size)
        const freePct = (freeTokens * 100.0) / totalSize;
        const freePctInt = Math.floor(freePct);

        // Format tokens in k with one decimal
        const freeDisplay = `${(freeTokens / 1000).toFixed(1)}k`;

        // Color based on free percentage
        let ctxColor;
        if (freePctInt > 50) {
            ctxColor = GREEN;
        } else if (freePctInt > 25) {
            ctxColor = YELLOW;
        } else {
            ctxColor = RED;
        }

        contextInfo = ` | ${ctxColor}${freeDisplay} free (${freePct.toFixed(1)}%)${RESET}`;
    }

    // Token metrics (without cost)
    let tokenMetrics = '';
    const totalInputTokens = data.context_window?.total_input_tokens || 0;
    const totalOutputTokens = data.context_window?.total_output_tokens || 0;

    // Get cache info from current_usage
    const cacheCreationTokens = data.context_window?.current_usage?.cache_creation_input_tokens || 0;
    const cacheReadTokens = data.context_window?.current_usage?.cache_read_input_tokens || 0;

    if (totalInputTokens > 0 || totalOutputTokens > 0) {
        const inK = Math.floor(totalInputTokens / 1000);
        const outK = Math.floor(totalOutputTokens / 1000);

        // Build token info string with colors: in=blue, out=magenta, cache=cyan
        // Format: [in:72k,out:83k,cache:41k]
        const cacheTotal = cacheCreationTokens + cacheReadTokens;
        let tokenInfo;
        if (cacheTotal > 0) {
            const cacheK = Math.floor(cacheTotal / 1000);
            tokenInfo = `${DIM}[${RESET}${BLUE}in:${inK}k${RESET}${DIM},${RESET}${MAGENTA}out:${outK}k${RESET}${DIM},${RESET}${CYAN}cache:${cacheK}k${RESET}${DIM}]${RESET}`;
        } else {
            tokenInfo = `${DIM}[${RESET}${BLUE}in:${inK}k${RESET}${DIM},${RESET}${MAGENTA}out:${outK}k${RESET}${DIM}]${RESET}`;
        }

        tokenMetrics = ` | ${tokenInfo}`;
    }

    // Output: [Model] directory | branch [changes] | XXk free (XX%) [AC] | [in:Xk,out:Xk,cache:Xk]
    console.log(`${DIM}[${model}]${RESET} ${BLUE}${dirName}${RESET}${gitInfo}${contextInfo}${acInfo}${tokenMetrics}`);
});
