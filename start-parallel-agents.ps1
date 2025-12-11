<#
.SYNOPSIS
Orchestrates the 10 deployment agents in parallel with optional dry-run.

.DESCRIPTION
Runs the existing deployment scripts in parallel jobs. Defaults to dry-run
so you can see what will execute. Pass -Execute to run. Logs land in
./agent-logs by default.

Credential handling:
- Reads SMB/user creds from env: TRUENAS_USERNAME and TRUENAS_PASSWORD.
- If missing, affected agents are skipped.

.EXAMPLE
.\start-parallel-agents.ps1              # dry-run, show plan
.\start-parallel-agents.ps1 -Execute     # run all agents in parallel
#>
param(
    [switch]$Execute,
    [string]$LogRoot = (Join-Path $PSScriptRoot "agent-logs"),
    [switch]$VerboseCommands
)

function New-Agent {
    param(
        [string]$Name,
        [string]$Category,
        [string]$Description,
        [hashtable]$Task,
        [string[]]$RequiresPaths = @(),
        [string[]]$RequiresCommands = @(),
        [switch]$NeedsCredential
    )

    [pscustomobject]@{
        Name              = $Name
        Category          = $Category
        Description       = $Description
        Task              = $Task
        RequiresPaths     = $RequiresPaths
        RequiresCommands  = $RequiresCommands
        NeedsCredential   = [bool]$NeedsCredential
    }
}

function Get-EnvCredential {
    param(
        [string]$UserVar = "TRUENAS_USERNAME",
        [string]$PassVar = "TRUENAS_PASSWORD"
    )

    $user = [Environment]::GetEnvironmentVariable($UserVar)
    $pass = [Environment]::GetEnvironmentVariable($PassVar)

    if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
        return $null
    }

    return [pscredential]::new($user, (ConvertTo-SecureString $pass -AsPlainText -Force))
}

function Test-Prerequisites {
    param(
        [pscustomobject]$Agent
    )

    foreach ($path in $Agent.RequiresPaths) {
        $fullPath = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $PSScriptRoot $path }
        if (-not (Test-Path $fullPath)) {
            return "Missing file: $fullPath"
        }
    }

    foreach ($cmd in $Agent.RequiresCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            return "Missing command: $cmd"
        }
    }

    if ($Agent.NeedsCredential -and -not (Get-EnvCredential)) {
        return "Missing TRUENAS_USERNAME/TRUENAS_PASSWORD environment variables"
    }

    return $null
}

function Start-AgentJob {
    param(
        [pscustomobject]$Agent,
        [switch]$Execute,
        [string]$LogRoot
    )

    $logFile = Join-Path $LogRoot ("{0}.log" -f $Agent.Name)
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null

    Start-Job -Name $Agent.Name -ScriptBlock {
        param($Agent, $Execute, $LogFile)

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] Starting $($Agent.Name)" | Tee-Object -FilePath $LogFile -Append | Out-Null

        if (-not $Execute) {
            "DRY RUN - not executing tasks" | Tee-Object -FilePath $LogFile -Append | Out-Null
            return
        }

        foreach ($step in $Agent.Task.Steps) {
            $cmd = $step.Command
            $args = $step.Arguments
            $workdir = $step.WorkDir

            if ($workdir) {
                Push-Location $workdir
            }

            try {
                $output = & $cmd @args 2>&1
                $output | Tee-Object -FilePath $LogFile -Append | Out-Null
            } catch {
                "ERROR: $($_.Exception.Message)" | Tee-Object -FilePath $LogFile -Append | Out-Null
            } finally {
                if ($workdir) { Pop-Location }
            }
        }

        $end = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$end] Completed $($Agent.Name)" | Tee-Object -FilePath $LogFile -Append | Out-Null
    } -ArgumentList $Agent, $Execute, $logFile
}

$AgentCredential = Get-EnvCredential
$AgentUser = if ($AgentCredential) { $AgentCredential.UserName } else { $null }
$AgentPass = if ($AgentCredential) { $AgentCredential.GetNetworkCredential().Password } else { $null }

$agents = @(
    (New-Agent -Name "Agent01-BabyNAS" -Category "Storage" -Description "Create datasets and SMB shares on Baby NAS" -Task @{
        Steps = @(
            @{ Command = "bash"; Arguments = @((Join-Path $PSScriptRoot "..\scripts\baby-nas\SETUP-BABY-NAS-DATASETS.sh")); WorkDir = (Join-Path $PSScriptRoot "..\scripts\baby-nas") },
            @{ Command = "bash"; Arguments = @((Join-Path $PSScriptRoot "..\scripts\baby-nas\SETUP-SMB-SHARES.sh")); WorkDir = (Join-Path $PSScriptRoot "..\scripts\baby-nas") }
        )
    } -RequiresPaths @("..\scripts\baby-nas\SETUP-BABY-NAS-DATASETS.sh","..\scripts\baby-nas\SETUP-SMB-SHARES.sh") -RequiresCommands @("bash")),

    (New-Agent -Name "Agent02-Veeam" -Category "Windows" -Description "Deploy Veeam Agent job to Baby NAS" -Task @{
        Steps = @(
            @{
                Command = (Join-Path $PSScriptRoot "DEPLOY-VEEAM-COMPLETE.ps1");
                Arguments = @(
                    "-SharePath", "\\baby.isn.biz\Veeam",
                    "-Username", $AgentUser,
                    "-Password", $AgentPass,
                    "-Schedule", "01:00",
                    "-RetentionDays", "7",
                    "-RunNow"
                );
                WorkDir = $PSScriptRoot;
                SupportsCredential = $true;
            }
        )
    } -RequiresPaths @("DEPLOY-VEEAM-COMPLETE.ps1")),

    (New-Agent -Name "Agent03-Phone-Backup" -Category "Windows" -Description "Mount SMB share and prep phone backup workspace" -Task @{
        Steps = @(
            @{
                Command = (Join-Path $PSScriptRoot "DEPLOY-PHONE-BACKUPS-WINDOWS.ps1");
                Arguments = @(
                    "-BabyNASHostname","baby.isn.biz",
                    "-BabyNASIP","172.21.203.18",
                    "-PhoneBackupShare","\\baby.isn.biz\PhoneBackups",
                    "-QuotaGB","500",
                    "-Username", $AgentUser,
                    "-Password", $AgentPass,
                    "-NoGUI"
                );
                WorkDir = $PSScriptRoot;
                SupportsCredential = $true;
            }
        )
    } -RequiresPaths @("DEPLOY-PHONE-BACKUPS-WINDOWS.ps1")),

    (New-Agent -Name "Agent04-iOS-Prep" -Category "Docs" -Description "Generate iOS backup handoff instructions" -Task @{
        Steps = @(
            @{
                Command = "pwsh";
                Arguments = @("-NoProfile","-Command","Get-Content TIME-MACHINE-MIGRATION-GUIDE.md | Select-Object -First 40");
                WorkDir = (Split-Path $PSScriptRoot -Parent);
            }
        )
    } -RequiresCommands @("pwsh") -RequiresPaths @("..\TIME-MACHINE-MIGRATION-GUIDE.md")),

    (New-Agent -Name "Agent05-TimeMachine" -Category "Mac" -Description "Prepare Time Machine dataset setup" -Task @{
        Steps = @(
            @{ Command = "bash"; Arguments = @((Join-Path $PSScriptRoot "..\scripts\time-machine-bare-metal-setup.sh")); WorkDir = (Join-Path $PSScriptRoot "..\scripts") }
        )
    } -RequiresCommands @("bash") -RequiresPaths @("..\scripts\time-machine-bare-metal-setup.sh")),

    (New-Agent -Name "Agent06-Monitoring" -Category "Monitoring" -Description "Install monitoring dashboard and alerts" -Task @{
        Steps = @(
            @{ Command = (Join-Path $PSScriptRoot "BACKUP-MONITORING-DASHBOARD.ps1"); Arguments = @(); WorkDir = $PSScriptRoot },
            @{ Command = (Join-Path $PSScriptRoot "BACKUP-ALERTING-SETUP.ps1"); Arguments = @("-ConfigPath", (Join-Path $PSScriptRoot "ALERTING-CONFIG-TEMPLATE.json")); WorkDir = $PSScriptRoot }
        )
    } -RequiresPaths @("BACKUP-MONITORING-DASHBOARD.ps1","BACKUP-ALERTING-SETUP.ps1","ALERTING-CONFIG-TEMPLATE.json")),

    (New-Agent -Name "Agent07-WireGuard" -Category "VPN" -Description "Configure Windows WireGuard client" -Task @{
        Steps = @(
            @{ Command = (Join-Path $PSScriptRoot "WIREGUARD-CLIENT-SETUP-WINDOWS.ps1"); Arguments = @("-ServerHost","73.140.158.252","-ServerPort","51820"); WorkDir = $PSScriptRoot }
        )
    } -RequiresPaths @("WIREGUARD-CLIENT-SETUP-WINDOWS.ps1")),

    (New-Agent -Name "Agent08-DR-Testing" -Category "DR" -Description "Run recovery test harness" -Task @{
        Steps = @(
            @{ Command = (Join-Path $PSScriptRoot "test-recovery.ps1"); Arguments = @(); WorkDir = $PSScriptRoot }
        )
    } -RequiresPaths @("test-recovery.ps1")),

    (New-Agent -Name "Agent09-Verification" -Category "Validation" -Description "Verify backups and system state" -Task @{
        Steps = @(
            @{ Command = (Join-Path $PSScriptRoot "VERIFY-ALL-BACKUPS.ps1"); Arguments = @(); WorkDir = $PSScriptRoot },
            @{ Command = (Join-Path $PSScriptRoot "check-systems-no-admin.ps1"); Arguments = @(); WorkDir = $PSScriptRoot }
        )
    } -RequiresPaths @("VERIFY-ALL-BACKUPS.ps1","check-systems-no-admin.ps1")),

    (New-Agent -Name "Agent10-Docs" -Category "Docs" -Description "Compile deployment summaries" -Task @{
        Steps = @(
            @{ Command = "pwsh"; Arguments = @("-NoProfile","-Command","Get-ChildItem *.md | Select-Object -First 5"); WorkDir = $PSScriptRoot }
        )
    } -RequiresCommands @("pwsh"))
)

# Summary view
$summary = foreach ($a in $agents) {
    [pscustomobject]@{
        Agent       = $a.Name
        Category    = $a.Category
        Description = $a.Description
        Execute     = $Execute.IsPresent
    }
}

Write-Host ""
Write-Host "Parallel Agent Orchestrator" -ForegroundColor Cyan
Write-Host "Execute mode: $($Execute.IsPresent)" -ForegroundColor Yellow
Write-Host ""
$summary | Format-Table -AutoSize

$jobs = @()
foreach ($agent in $agents) {
    $preReqError = Test-Prerequisites -Agent $agent
    if ($preReqError) {
        Write-Host "Skipping $($agent.Name): $preReqError" -ForegroundColor Yellow
        continue
    }

    if ($VerboseCommands) {
        Write-Host "Starting $($agent.Name)" -ForegroundColor Gray
    }

    $jobs += Start-AgentJob -Agent $agent -Execute:$Execute -LogRoot $LogRoot
}

if (-not $Execute) {
    Write-Host ""
    Write-Host "Dry run complete. Use -Execute to run agents." -ForegroundColor Green
    return
}

Write-Host ""
Write-Host "Waiting for jobs to complete..." -ForegroundColor Cyan
if ($jobs) {
    Wait-Job -Job $jobs | Out-Null
    Receive-Job -Job $jobs | Out-Null
}

Write-Host "All agent jobs finished. Logs: $LogRoot" -ForegroundColor Green
