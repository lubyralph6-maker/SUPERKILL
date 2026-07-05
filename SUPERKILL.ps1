# SuperKill launcher (same as SUPERKILL.ps1)
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\SuperKill.ps1

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ScriptFolder {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return (Split-Path -Parent $MyInvocation.MyCommand.Path) }
    return $PWD.Path
}

function Find-LocalExe {
    param([string[]]$Folders)

    $names = @('SuperKill.exe', 'SUPERKILL.exe', 'superkill.exe')
    foreach ($folder in $Folders) {
        if (-not $folder) { continue }
        foreach ($name in $names) {
            $candidate = Join-Path $folder $name
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
        try {
            $hit = Get-ChildItem -LiteralPath $folder -Filter '*.exe' -File -ErrorAction Stop |
                Where-Object { $_.Name -match 'superkill' } |
                Select-Object -First 1
            if ($hit) { return $hit.FullName }
        } catch {}
    }
    return $null
}

function Stop-OldInstance {
    Get-Process -Name 'SuperKill' -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Start-SuperKillApp {
    param(
        [string]$ExePath,
        [string]$WorkDir
    )

    if (-not (Test-Path -LiteralPath $ExePath)) {
        Write-Host "ERROR: not found -> $ExePath" -ForegroundColor Red
        exit 1
    }

    Stop-OldInstance

    try {
        if (-not (Test-IsAdmin)) {
            Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir -Verb RunAs | Out-Null
        } else {
            Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir | Out-Null
        }
        Write-Host 'OK' -ForegroundColor Green
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

$scriptDir = Get-ScriptFolder
$localExe = Find-LocalExe @($scriptDir, $PWD.Path, (Join-Path $scriptDir 'bin'))

if ($localExe) {
    Start-SuperKillApp -ExePath $localExe -WorkDir (Split-Path -Parent $localExe)
    exit 0
}

Write-Host 'ERROR: SuperKill.exe not found next to this script.' -ForegroundColor Red
Write-Host "Put SuperKill.exe in: $scriptDir" -ForegroundColor Yellow
exit 1
