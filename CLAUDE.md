# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

System Integration Quality Control - a shell-based scanning pipeline that runs security and SEO audits against GitHub repositories and web URLs. Scans are triggered via GitHub Actions (`workflow_dispatch`) or locally, and results are published as static HTML reports to GitHub Pages.

Primary language is **Traditional Chinese (zh-TW)** for UI text and comments.

## Running Scans

```bash
# Full local run (installs tools, clones target repos, runs all scanners, generates reports)
export REPOS_JSON='["https://github.com/owner/repo"]'
export WEB_URL="https://your-site.com"   # optional - enables pentest + SEO scans
export SCAN_DEPTH="standard"              # quick | standard | deep
export PROJECT_NAME="my-project"          # optional - groups scan history
./scripts/entrypoint.sh

# Skip tool installation if already set up
SKIP_SETUP=true ./scripts/entrypoint.sh

# Pass args directly
PAT_TOKEN="ghp_xxx" ./scripts/entrypoint.sh '["https://github.com/owner/repo"]' "https://site.com"
```

Reports are written to `docs/scans/<SCAN_ID>/` where SCAN_ID is a timestamp (`YYYYMMDD-HHMMSS`).

## Architecture

### Execution Flow

`entrypoint.sh` → `setup-tools.sh` → `scan-all.sh` → individual scanners → report generators

### `scan-all.sh` Orchestration

1. **Per-repo loop**: clones each repo from `REPOS_JSON` into `.work/target-<name>`, runs SAST/vulnerability/SSDLC scanners against it, generates a per-project HTML report, then cleans up the clone.
2. **Web URL scans** (only if `WEB_URL` is set): runs pentest (`pentest.sh`) and SEO checks (`seo.sh` which delegates to 6 sub-scanners in `scripts/scanners/seo/`).
3. **Report generation**: `generate-index.sh` builds the per-scan index page, per-project history pages (`docs/projects/<name>/index.html`), and the top-level `docs/index.html` project listing.

### Scanner Output Convention

Every scanner writes a `*-result.json` file to its output directory with a consistent shape:
- `status`: "completed" | "skipped" | "error"
- `summary`: object with pass/fail/total counts (varies per scanner)
- Optional detailed report files (e.g., `semgrep-report.json`, `trivy-report.txt`, `nuclei-report.txt`)

Report generators read these JSON files via `jq` to build HTML tables and summary cards.

### Scanner → Tool Mapping

| Scanner | Tool | Requires |
|---------|------|----------|
| `sast.sh` | Semgrep | Python (pip) |
| `vulnerability.sh` | Trivy | Docker |
| `ssdlc.sh` | Checkov + file checks | Python (pip) |
| `pentest.sh` | OWASP ZAP + Nuclei | Docker + Nuclei binary |
| `seo.sh` | curl + jq + grep | Built-in |

### Adding a New Scanner

1. Create `scripts/scanners/<name>.sh` — accept `<target_dir> <output_dir>`, write `<name>-result.json`
2. Call it from `scripts/scan-all.sh` at the appropriate point (repo loop or web URL section)
3. Add result rendering in the relevant report generator (`generate-project-report.sh` or `generate-index.sh`)

## Key Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `REPOS_JSON` | At least one of REPOS_JSON or WEB_URL | JSON array of GitHub repo URLs |
| `WEB_URL` | At least one of REPOS_JSON or WEB_URL | Target URL for pentest and SEO scans |
| `PROJECT_NAME` | No | Groups scan history; fallback: WEB_URL domain → first repo basename → `"unknown"` |
| `SCAN_DEPTH` | No | `quick` / `standard` (default) / `deep` |
| `PAT_TOKEN` | No | GitHub PAT for private repos |
| `SKIP_SETUP` | No | Set `true` to skip tool installation |

## GitHub Actions

The workflow (`.github/workflows/security-scan.yml`) is manually triggered via `workflow_dispatch`. On failure it auto-creates a GitHub issue with the `security` and `scan-failed` labels. Reports are deployed to GitHub Pages via `peaceiris/actions-gh-pages@v4`.
