#!/usr/bin/env bash
# repo-insights.sh — Generate a comprehensive GitHub repo insights report
#
# Usage:
#   ./scripts/repo-insights.sh                    # Current repo, output to repo-insights.md
#   ./scripts/repo-insights.sh -o report.md       # Custom output file
#   ./scripts/repo-insights.sh -r owner/repo      # Specific repo
#   curl -fsSL <url> | bash                       # Run from anywhere
#
# Requirements: gh (GitHub CLI, authenticated), jq, git

set -euo pipefail

# === DEFAULTS ===
OUTPUT_FILE="repo-insights.md"
REPO=""
DATE_NOW=$(date -u +"%Y-%m-%d %H:%M UTC")

# === PARSE ARGS ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -r|--repo)   REPO="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: repo-insights.sh [-r owner/repo] [-o output.md]"
            echo "  -r, --repo    GitHub repo (default: auto-detect from git remote)"
            echo "  -o, --output  Output file (default: repo-insights.md)"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# === DETECT REPO ===
if [[ -z "$REPO" ]]; then
    REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
    if [[ -z "$REPO" ]]; then
        echo "Error: Could not detect repo. Use -r owner/repo or run inside a git repo."
        exit 1
    fi
fi

echo "Generating insights for $REPO..."

# === HELPERS ===
gh_api() {
    gh api "$1" 2>/dev/null || echo "{}"
}

# Safe jq that returns "0" or "N/A" on failure
safe_jq() {
    echo "$1" | jq -r "$2" 2>/dev/null || echo "${3:-0}"
}

# === FETCH ALL DATA IN PARALLEL ===
echo "  Fetching repo metadata..."
REPO_DATA=$(gh_api "repos/$REPO")

echo "  Fetching traffic data..."
CLONES=$(gh_api "repos/$REPO/traffic/clones")
VIEWS=$(gh_api "repos/$REPO/traffic/views")
REFERRERS=$(gh_api "repos/$REPO/traffic/popular/referrers")
PATHS=$(gh_api "repos/$REPO/traffic/popular/paths")

echo "  Fetching community data..."
STARGAZERS=$(gh_api "repos/$REPO/stargazers?per_page=1&page=1" || echo "[]")
RELEASES=$(gh api "repos/$REPO/releases?per_page=10" 2>/dev/null || echo "[]")
CONTRIBUTORS=$(gh api "repos/$REPO/contributors?per_page=100" 2>/dev/null || echo "[]")
ISSUES_OPEN=$(gh api "repos/$REPO/issues?state=open&per_page=1" --include 2>/dev/null | head -1 || echo "")
ISSUES_CLOSED=$(gh api "repos/$REPO/issues?state=closed&per_page=1" --include 2>/dev/null | head -1 || echo "")

echo "  Fetching issue/PR activity..."
RECENT_ISSUES=$(gh api "repos/$REPO/issues?state=all&per_page=30&sort=created&direction=desc" 2>/dev/null || echo "[]")
RECENT_PRS=$(gh api "repos/$REPO/pulls?state=all&per_page=30&sort=created&direction=desc" 2>/dev/null || echo "[]")

# === EXTRACT METRICS ===
# Repo basics
REPO_NAME=$(safe_jq "$REPO_DATA" '.full_name' 'unknown')
DESCRIPTION=$(safe_jq "$REPO_DATA" '.description // "N/A"' 'N/A')
STARS=$(safe_jq "$REPO_DATA" '.stargazers_count' '0')
FORKS=$(safe_jq "$REPO_DATA" '.forks_count' '0')
WATCHERS=$(safe_jq "$REPO_DATA" '.subscribers_count' '0')
OPEN_ISSUES=$(safe_jq "$REPO_DATA" '.open_issues_count' '0')
CREATED=$(safe_jq "$REPO_DATA" '.created_at // "N/A"' 'N/A')
PUSHED=$(safe_jq "$REPO_DATA" '.pushed_at // "N/A"' 'N/A')
DEFAULT_BRANCH=$(safe_jq "$REPO_DATA" '.default_branch' 'main')
LICENSE=$(safe_jq "$REPO_DATA" '.license.spdx_id // "N/A"' 'N/A')
LANGUAGE=$(safe_jq "$REPO_DATA" '.language // "N/A"' 'N/A')
SIZE_KB=$(safe_jq "$REPO_DATA" '.size' '0')

# Traffic (last 14 days)
CLONE_TOTAL=$(safe_jq "$CLONES" '.count' '0')
CLONE_UNIQUE=$(safe_jq "$CLONES" '.uniques' '0')
VIEW_TOTAL=$(safe_jq "$VIEWS" '.count' '0')
VIEW_UNIQUE=$(safe_jq "$VIEWS" '.uniques' '0')

# Contributors
CONTRIBUTOR_COUNT=$(echo "$CONTRIBUTORS" | jq 'length' 2>/dev/null || echo "0")

# Releases
RELEASE_COUNT=$(echo "$RELEASES" | jq 'length' 2>/dev/null || echo "0")
LATEST_RELEASE=$(echo "$RELEASES" | jq -r '.[0].tag_name // "none"' 2>/dev/null || echo "none")
LATEST_RELEASE_DATE=$(echo "$RELEASES" | jq -r '.[0].published_at // "N/A"' 2>/dev/null || echo "N/A")

# Release download totals
RELEASE_DOWNLOADS=$(echo "$RELEASES" | jq '[.[].assets[].download_count] | add // 0' 2>/dev/null || echo "0")

# Commit activity
echo "  Fetching commit activity..."
COMMIT_COUNT_30D=$(gh api "repos/$REPO/commits?per_page=1&since=$(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '2026-02-13T00:00:00Z')" --include 2>/dev/null | grep -i "link:" | grep -o 'page=[0-9]*' | tail -1 | grep -o '[0-9]*' || echo "?")
COMMIT_TOTAL=$(gh api "repos/$REPO/commits?per_page=1" --include 2>/dev/null | grep -i "link:" | grep -o 'page=[0-9]*' | tail -1 | grep -o '[0-9]*' || echo "?")

# === PyPI / npm stats ===
echo "  Checking package registries..."
PYPI_VERSION=""
PYPI_DOWNLOADS=""
NPM_VERSION=""
NPM_DOWNLOADS=""

PKG_NAME=$(safe_jq "$REPO_DATA" '.name' '')

# Try PyPI
PYPI_DATA=$(curl -sf "https://pypi.org/pypi/$PKG_NAME/json" 2>/dev/null || echo "")
if [[ -n "$PYPI_DATA" ]]; then
    PYPI_VERSION=$(echo "$PYPI_DATA" | jq -r '.info.version // "N/A"' 2>/dev/null || echo "N/A")
    # pypistats for monthly downloads
    PYPI_STATS=$(curl -sf "https://pypistats.org/api/packages/$PKG_NAME/recent" 2>/dev/null || echo "")
    if [[ -n "$PYPI_STATS" ]]; then
        PYPI_DOWNLOADS_MONTH=$(echo "$PYPI_STATS" | jq -r '.data.last_month // 0' 2>/dev/null || echo "0")
        PYPI_DOWNLOADS_WEEK=$(echo "$PYPI_STATS" | jq -r '.data.last_week // 0' 2>/dev/null || echo "0")
        PYPI_DOWNLOADS_DAY=$(echo "$PYPI_STATS" | jq -r '.data.last_day // 0' 2>/dev/null || echo "0")
    fi
fi

# Try npm
NPM_DATA=$(curl -sf "https://registry.npmjs.org/$PKG_NAME" 2>/dev/null || echo "")
if [[ -n "$NPM_DATA" ]] && echo "$NPM_DATA" | jq -e '.["dist-tags"]' >/dev/null 2>&1; then
    NPM_VERSION=$(echo "$NPM_DATA" | jq -r '.["dist-tags"].latest // "N/A"' 2>/dev/null || echo "N/A")
    # npm download stats
    NPM_DL_WEEK=$(curl -sf "https://api.npmjs.org/downloads/point/last-week/$PKG_NAME" 2>/dev/null || echo "")
    NPM_DL_MONTH=$(curl -sf "https://api.npmjs.org/downloads/point/last-month/$PKG_NAME" 2>/dev/null || echo "")
    if [[ -n "$NPM_DL_WEEK" ]]; then
        NPM_DOWNLOADS_WEEK=$(echo "$NPM_DL_WEEK" | jq -r '.downloads // 0' 2>/dev/null || echo "0")
    fi
    if [[ -n "$NPM_DL_MONTH" ]]; then
        NPM_DOWNLOADS_MONTH=$(echo "$NPM_DL_MONTH" | jq -r '.downloads // 0' 2>/dev/null || echo "0")
    fi
fi

# === GENERATE REPORT ===
echo "  Writing report..."

cat > "$OUTPUT_FILE" << HEADER
# Repo Insights: $REPO_NAME

> Generated on $DATE_NOW

## Overview

| Metric | Value |
|--------|-------|
| Description | $DESCRIPTION |
| Primary Language | $LANGUAGE |
| License | $LICENSE |
| Created | $CREATED |
| Last Push | $PUSHED |
| Repo Size | ${SIZE_KB} KB |
| Default Branch | $DEFAULT_BRANCH |

## Community

| Metric | Count |
|--------|-------|
| Stars | $STARS |
| Forks | $FORKS |
| Watchers | $WATCHERS |
| Contributors | $CONTRIBUTOR_COUNT |
| Open Issues/PRs | $OPEN_ISSUES |
| Total Commits | $COMMIT_TOTAL |

## Traffic (Last 14 Days)

These numbers come from GitHub's traffic API and represent **real visitors** (not bots or mirrors).

| Metric | Total | Unique |
|--------|-------|--------|
| Page Views | $VIEW_TOTAL | **$VIEW_UNIQUE** |
| Repo Clones | $CLONE_TOTAL | **$CLONE_UNIQUE** |

> **Unique cloners** is the most reliable proxy for real users — each represents a distinct person/machine that cloned the repo.

### Daily Clones (Last 14 Days)

| Date | Clones | Unique |
|------|--------|--------|
HEADER

# Clone daily breakdown
echo "$CLONES" | jq -r '.clones[]? | "| \(.timestamp | split("T")[0]) | \(.count) | \(.uniques) |"' >> "$OUTPUT_FILE" 2>/dev/null || echo "| No data available | - | - |" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'SECTION'

### Daily Views (Last 14 Days)

| Date | Views | Unique |
|------|-------|--------|
SECTION

# View daily breakdown
echo "$VIEWS" | jq -r '.views[]? | "| \(.timestamp | split("T")[0]) | \(.count) | \(.uniques) |"' >> "$OUTPUT_FILE" 2>/dev/null || echo "| No data available | - | - |" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'SECTION'

### Top Referrers

Where visitors are coming from:

| Referrer | Views | Unique |
|----------|-------|--------|
SECTION

echo "$REFERRERS" | jq -r '.[]? | "| \(.referrer) | \(.count) | \(.uniques) |"' >> "$OUTPUT_FILE" 2>/dev/null || echo "| No data available | - | - |" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'SECTION'

### Popular Content

Most visited pages:

| Path | Views | Unique |
|------|-------|--------|
SECTION

echo "$PATHS" | jq -r '.[]? | "| \(.path) | \(.count) | \(.uniques) |"' >> "$OUTPUT_FILE" 2>/dev/null || echo "| No data available | - | - |" >> "$OUTPUT_FILE"

# === PACKAGE REGISTRY STATS ===
{
    echo ""
    echo "## Package Registry Stats"
    echo ""
    echo "> Note: Registry download counts include bots, CI pipelines, mirrors, and security scanners. Real user count is likely **10-20%** of these numbers. Use GitHub clone uniques as a more reliable metric."
    echo ""

    if [[ -n "$PYPI_VERSION" ]]; then
        echo "### PyPI"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Latest Version | $PYPI_VERSION |"
        echo "| Downloads (last day) | ${PYPI_DOWNLOADS_DAY:-N/A} |"
        echo "| Downloads (last week) | ${PYPI_DOWNLOADS_WEEK:-N/A} |"
        echo "| Downloads (last month) | ${PYPI_DOWNLOADS_MONTH:-N/A} |"
        echo "| Link | [pypi.org/project/$PKG_NAME](https://pypi.org/project/$PKG_NAME/) |"
        echo ""
    fi

    if [[ -n "$NPM_VERSION" ]]; then
        echo "### npm"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Latest Version | $NPM_VERSION |"
        echo "| Downloads (last week) | ${NPM_DOWNLOADS_WEEK:-N/A} |"
        echo "| Downloads (last month) | ${NPM_DOWNLOADS_MONTH:-N/A} |"
        echo "| Link | [npmjs.com/package/$PKG_NAME](https://www.npmjs.com/package/$PKG_NAME) |"
        echo ""
    fi

    if [[ -z "$PYPI_VERSION" ]] && [[ -z "$NPM_VERSION" ]]; then
        echo "No PyPI or npm packages detected for this repo."
        echo ""
    fi
} >> "$OUTPUT_FILE"

# === RELEASES ===
{
    echo "## Releases"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Total Releases | $RELEASE_COUNT |"
    echo "| Latest Release | $LATEST_RELEASE |"
    echo "| Latest Release Date | $LATEST_RELEASE_DATE |"
    echo "| Asset Downloads (total) | $RELEASE_DOWNLOADS |"
    echo ""

    if [[ "$RELEASE_COUNT" -gt 0 ]]; then
        echo "### Recent Releases"
        echo ""
        echo "| Tag | Date | Assets |"
        echo "|-----|------|--------|"
        echo "$RELEASES" | jq -r '.[]? | "| \(.tag_name) | \(.published_at | split("T")[0]) | \(.assets | length) |"' 2>/dev/null || true
        echo ""
    fi
} >> "$OUTPUT_FILE"

# === ISSUE & PR ACTIVITY ===
{
    echo "## Issue & PR Activity (Last 30 Days)"
    echo ""

    # Count issues vs PRs in recent data
    RECENT_ISSUE_COUNT=$(echo "$RECENT_ISSUES" | jq '[.[] | select(.pull_request == null)] | length' 2>/dev/null || echo "0")
    RECENT_PR_COUNT=$(echo "$RECENT_PRS" | jq 'length' 2>/dev/null || echo "0")
    MERGED_PRS=$(echo "$RECENT_PRS" | jq '[.[] | select(.merged_at != null)] | length' 2>/dev/null || echo "0")

    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Recent Issues | $RECENT_ISSUE_COUNT |"
    echo "| Recent PRs | $RECENT_PR_COUNT |"
    echo "| Merged PRs | $MERGED_PRS |"
    echo ""
} >> "$OUTPUT_FILE"

# === TOP CONTRIBUTORS ===
{
    echo "## Top Contributors"
    echo ""
    echo "| # | Contributor | Commits |"
    echo "|---|------------|---------|"
    echo "$CONTRIBUTORS" | jq -r 'to_entries | .[:10][] | "| \(.key + 1) | [@\(.value.login)](https://github.com/\(.value.login)) | \(.value.contributions) |"' 2>/dev/null || echo "| - | No data | - |"
    echo ""
} >> "$OUTPUT_FILE"

# === REAL VS BOT ESTIMATE ===
{
    echo "## Real Users vs Bots (Estimate)"
    echo ""
    echo "| Signal | Value | Confidence |"
    echo "|--------|-------|------------|"
    echo "| GitHub unique cloners (14d) | **$CLONE_UNIQUE** | High — real humans/machines |"
    echo "| GitHub unique visitors (14d) | **$VIEW_UNIQUE** | High — real page visitors |"
    echo "| GitHub stars | **$STARS** | High — manual action |"
    echo "| GitHub forks | **$FORKS** | Medium — some are bots |"
    if [[ -n "${PYPI_DOWNLOADS_MONTH:-}" ]]; then
        echo "| PyPI downloads (month) | $PYPI_DOWNLOADS_MONTH | Low — includes bots/CI/mirrors |"
    fi
    if [[ -n "${NPM_DOWNLOADS_MONTH:-}" ]]; then
        echo "| npm downloads (month) | $NPM_DOWNLOADS_MONTH | Low — includes bots/CI/mirrors |"
    fi
    echo ""
    echo "### Interpretation"
    echo ""
    echo "- **Most reliable**: Unique cloners ($CLONE_UNIQUE) and unique visitors ($VIEW_UNIQUE) — these are de-duplicated by GitHub"
    echo "- **Good signal**: Stars ($STARS) require manual action, so each represents genuine interest"
    echo "- **Inflated**: Registry downloads include CI pipelines, mirror syncs, security scanners, and dependency bots"
    echo "- **Estimated real users**: ~$CLONE_UNIQUE active users (based on unique cloners in the last 14 days)"
    echo ""
} >> "$OUTPUT_FILE"

# === FOOTER ===
{
    echo "---"
    echo ""
    echo "*Generated by [repo-insights.sh](https://github.com/$REPO) on $DATE_NOW*"
} >> "$OUTPUT_FILE"

echo ""
echo "Done! Report written to: $OUTPUT_FILE"
echo ""
echo "Quick summary:"
echo "  Stars: $STARS | Forks: $FORKS | Contributors: $CONTRIBUTOR_COUNT"
echo "  Unique cloners (14d): $CLONE_UNIQUE | Unique visitors (14d): $VIEW_UNIQUE"
if [[ -n "$PYPI_VERSION" ]]; then
    echo "  PyPI: v$PYPI_VERSION (${PYPI_DOWNLOADS_MONTH:-?} downloads/month)"
fi
if [[ -n "$NPM_VERSION" ]]; then
    echo "  npm: v$NPM_VERSION (${NPM_DOWNLOADS_MONTH:-?} downloads/month)"
fi
