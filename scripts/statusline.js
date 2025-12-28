#!/usr/bin/env node
/**
 * Node.js status line script for Claude Code
 * Usage: Copy to ~/.claude/statusline.js and make executable
 *
 * Configuration:
 * Create/edit ~/.claude/statusline.conf and set:
 *
 *   autocompact=true   (when autocompact is enabled in Claude Code - default)
 *   autocompact=false  (when you disable autocompact via /config in Claude Code)
 *
 *   token_detail=true  (show exact token count like 64,000 - default)
 *   token_detail=false (show abbreviated tokens like 64.0k)
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
            stdio: ['pipe', 'pipe', 'pipe'],
        }).trim();

        if (!branch) {
            return '';
        }

        // Count changes
        const status = execSync('git --no-optional-locks status --porcelain', {
            cwd: projectDir,
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe'],
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

function readConfig() {
    const config = {
        autocompact: true, // Default: enabled
        tokenDetail: true, // Default: show exact count
    };
    const configPath = path.join(os.homedir(), '.claude', 'statusline.conf');
    if (!fs.existsSync(configPath)) {
        return config;
    }

    try {
        const content = fs.readFileSync(configPath, 'utf8');
        for (const line of content.split('\n')) {
            const trimmed = line.trim();
            if (trimmed.startsWith('#') || !trimmed.includes('=')) {
                continue;
            }
            const [key, value] = trimmed.split('=', 2);
            const keyTrimmed = key.trim();
            const valueTrimmed = value.trim().toLowerCase();
            if (keyTrimmed === 'autocompact') {
                config.autocompact = valueTrimmed !== 'false';
            } else if (keyTrimmed === 'token_detail') {
                config.tokenDetail = valueTrimmed !== 'false';
            }
        }
    } catch {
        // Ignore errors
    }
    return config;
}

let input = '';

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => (input += chunk));

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

    // Read settings from config file
    const config = readConfig();
    const autocompactEnabled = config.autocompact;
    const tokenDetail = config.tokenDetail;

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
            const bufferK = Math.floor(autocompactBuffer / 1000);
            acInfo = ` ${DIM}[AC:${bufferK}k]${RESET}`;
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

        // Format tokens based on token_detail setting
        const freeDisplay = tokenDetail
            ? freeTokens.toLocaleString('en-US')
            : `${(freeTokens / 1000).toFixed(1)}k`;

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

    // Output: [Model] directory | branch [changes] | XXk free (XX%) [AC]
    console.log(
        `${DIM}[${model}]${RESET} ${BLUE}${dirName}${RESET}${gitInfo}${contextInfo}${acInfo}`
    );
});
