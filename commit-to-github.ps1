# Commit Changes to GitHub
# This script safely commits changes while protecting sensitive files

param(
    [string]$CommitMessage = "Add configuration, domain names, and automation scripts",
    [switch]$Push = $false
)

Write-Host "=== GitHub Commit Helper ===" -ForegroundColor Cyan
Write-Host ""

# Check if git is available
Write-Host "1. Checking git status..." -ForegroundColor Yellow
git status >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ✗ Git not found or not in a git repository" -ForegroundColor Red
    exit 1
}

Write-Host "   ✓ Git repository found" -ForegroundColor Green
Write-Host ""

# Show current status
Write-Host "2. Current Git Status:" -ForegroundColor Yellow
Write-Host ""
git status --short

Write-Host ""
Write-Host "3. Files that WILL be committed:" -ForegroundColor Cyan
# These are the safe files to commit
$filesToCommit = @(
    "*.ps1",           # PowerShell scripts
    "*.py",            # Python scripts
    "*.sh",            # Bash scripts
    "*.md",            # Documentation
    ".env.example",    # Template (no secrets)
    ".gitignore",      # Git config
    "monitoring-config.json"  # Template config
)

$stagedFiles = @()

# Stage the safe files
foreach ($pattern in $filesToCommit) {
    $files = git diff-index --cached --name-only HEAD | Where-Object { $_ -like $pattern }
    if ($files) {
        foreach ($file in $files) {
            git add $file 2>$null
            $stagedFiles += $file
        }
    }

    # Also stage untracked files
    $untracked = git ls-files -o --exclude-standard | Where-Object { $_ -like $pattern }
    if ($untracked) {
        foreach ($file in $untracked) {
            git add $file 2>$null
            $stagedFiles += $file
        }
    }
}

if ($stagedFiles.Count -eq 0) {
    Write-Host "   No files staged for commit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. Files being protected (NOT committed):" -ForegroundColor Yellow
    git status --short | Where-Object { $_ -like "*M .env*" -or $_ -like "*M *log*" }
    Write-Host ""
    Write-Host "Tip: Use 'git status' to see all changes" -ForegroundColor Gray
    exit 0
}

Write-Host ""
foreach ($file in $stagedFiles) {
    Write-Host "   + $file" -ForegroundColor Green
}

Write-Host ""
Write-Host "4. Files being PROTECTED (NOT committed):" -ForegroundColor Yellow
Write-Host "   - .env (production credentials)" -ForegroundColor Red
Write-Host "   - .env.local (machine-specific)" -ForegroundColor Red
Write-Host "   - .env.staging (staging credentials)" -ForegroundColor Red
Write-Host "   - .env.production (production credentials)" -ForegroundColor Red
Write-Host "   - C:\Logs (runtime logs)" -ForegroundColor Red
Write-Host "   - agent-logs/ (execution output)" -ForegroundColor Red

Write-Host ""
Write-Host "5. Commit Message:" -ForegroundColor Yellow
Write-Host "   $CommitMessage" -ForegroundColor Cyan

Write-Host ""
$response = Read-Host "Proceed with commit? (yes/no)"

if ($response -ne "yes") {
    Write-Host "   Cancelled" -ForegroundColor Gray
    git reset HEAD . 2>$null
    exit 0
}

Write-Host ""
Write-Host "Creating commit..." -ForegroundColor Yellow

$commitCmd = @"
git commit -m "$CommitMessage

🤖 Generated with Claude Code

Changes:
- Added configuration files (.env templates and examples)
- Added domain name support (babynas.isndotbiz.com)
- Added API key generation script
- Added Z: drive mapping setup script
- Added VM RAM reduction script
- Updated .gitignore for environment files
- Added configuration guide documentation"
@

Invoke-Expression $commitCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Commit created successfully" -ForegroundColor Green
} else {
    Write-Host "   ✗ Commit failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "6. Commit Details:" -ForegroundColor Yellow
git log -1 --oneline

# Ask about push
Write-Host ""
if ($Push) {
    Write-Host "7. Pushing to GitHub..." -ForegroundColor Yellow
    git push
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Pushed to GitHub" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Push failed" -ForegroundColor Red
        Write-Host "   Try manually: git push" -ForegroundColor Gray
    }
} else {
    Write-Host "7. Push Changes?" -ForegroundColor Yellow
    $pushResponse = Read-Host "Push to GitHub now? (yes/no)"
    if ($pushResponse -eq "yes") {
        git push
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Pushed to GitHub" -ForegroundColor Green
        } else {
            Write-Host "✗ Push failed - try: git push" -ForegroundColor Red
        }
    } else {
        Write-Host "Use 'git push' when ready to sync" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "✓ Complete!" -ForegroundColor Cyan
