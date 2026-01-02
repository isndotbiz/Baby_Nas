# Repository Guidelines

## Project Structure & Module Organization
- PowerShell automation lives at the repo root; numbered scripts (`1-*.ps1` through `5-*.ps1`) reflect the execution order for backup setup, monitoring, and scheduling.
- TrueNAS API helpers and utilities are the Python entry points (`truenas-*.py`) plus supporting tests (`test-truenas-tools.py`) and requirements in `requirements.txt`.
- Monitoring and automation readmes (`FULL-AUTOMATION*.md`, `MONITORING_AND_AUTOMATION_README.md`, `START_HERE*.md`) document workflow expectations; keep related updates in the same file family.
- The `veeam/` directory contains Veeam-specific deployment scripts and quick start notes; do not mix general Windows backup changes into that folder.
- Example configs and state files include `monitoring-config.json`, `SETUP_STATUS.txt`, and `vm-*-output.txt`; treat these as reference, not as secrets.
- RAG system mirror targets the main NAS at `/mnt/tank/rag-system`; connection details live in `.env.local` and `TRUENAS-RAG-SYNC.md`.

## Build, Test, and Development Commands
- Install Python dependencies for API tools: `python -m pip install -r requirements.txt`.
- Dry-run or exercise PowerShell flows: `pwsh -File 3-backup-wsl.ps1 -BackupPath "X:\\WSLBackups" -WhatIf` and `pwsh -File 5-schedule-tasks.ps1 -WhatIf` for scheduled tasks.
- Basic syntax check for the main automation script: `pwsh -File test-syntax.ps1`.
- Validate TrueNAS API tooling end-to-end: `python test-truenas-tools.py` (expects `~/.truenas/config.json` to exist).
- For Veeam flows, run targeted scripts from `veeam/` with `-WhatIf` where available before touching production backups.

## Coding Style & Naming Conventions
- PowerShell: 4-space indentation, Verb-Noun function names, and hyphenated script filenames; prefer explicit parameters over hardcoded paths. Keep user-facing `Write-Host` messages concise and colored only when helpful.
- Python: follow PEP 8; use type-friendly variable names and keep CLI entry points in `if __name__ == "__main__":` guards.
- Preserve numeric prefixes on workflow scripts to maintain ordering; add new stages using the next available integer.

## Testing Guidelines
- Add focused checks beside the feature you touch (e.g., new `*-test.ps1` or pytest-style helpers) and wire them into existing validation scripts when possible.
- Prefer non-destructive verification first (`-WhatIf`, mock IPs), then document any required admin privileges.
- Capture sample output or logs (redacted) when validating network-sensitive steps; avoid committing generated logs from `C:\\Logs`.

## Commit & Pull Request Guidelines
- Commit messages should stay short, present-tense, and imperative (e.g., `Update replication checks`, `Fix dashboard auth flow`); group related script and doc changes together.
- PRs should include: purpose, key changes, how to run the relevant validation commands, and any risk notes (network, admin rights, downtime).
- Link issues or tickets when available; attach screenshots or console snippets for dashboard or monitoring changes to show expected output.

## Security & Configuration Tips
- Never commit secrets, API keys, or real host IP/passwords; sample creds belong only in parameter defaults. Keep personal configs in `~/.truenas/` and excluded from version control.
- Validate paths before writing to disks; scripts default to `C:\\Logs` and backup drives (e.g., `X:\\`)—keep these overridable via parameters or config.
- Store TrueNAS sync credentials in `.env.local`; keep `.env` and `.env.local` out of git.
