param(
    [string]$InstallPath = ''
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Public download URLs only — no keys, passwords, or secrets in this script.
$RepoRaw = 'https://raw.githubusercontent.com/lubyralph6-maker/SUPERKILL/main'
$ScriptUrl = "$RepoRaw/SUPERKILL.ps1"
$ExeUrl = "$RepoRaw/SuperKill.exe"
$ExeName = 'SuperKill.exe'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SearchPaths {
    $paths = New-Object System.Collections.Generic.List[string]
    if ($PSScriptRoot) { [void]$paths.Add($PSScriptRoot) }
    if ($PWD.Path) { [void]$paths.Add($PWD.Path) }
    if ($PSScriptRoot) { [void]$paths.Add((Join-Path $PSScriptRoot 'bin')) }
    return $paths
}

function Find-LocalExe {
    foreach ($folder in (Get-SearchPaths)) {
        if (-not $folder) { continue }
        foreach ($name in @('SuperKill.exe', 'SUPERKILL.exe')) {
            $full = Join-Path $folder $name
            if (Test-Path -LiteralPath $full) {
                return (Resolve-Path -LiteralPath $full).Path
            }
        }
    }
    return $null
}

function Get-InstallFolder {
    if ($InstallPath -and (Test-Path -LiteralPath $InstallPath)) {
        return (Resolve-Path -LiteralPath $InstallPath).Path
    }
    if ($InstallPath) {
        return (New-Item -ItemType Directory -Force -Path $InstallPath).FullName
    }
    return (New-Item -ItemType Directory -Force -Path (Join-Path $env:LOCALAPPDATA 'SuperKill')).FullName
}

function Stop-OldInstance {
    Get-Process -Name 'SuperKill' -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Start-App {
    param(
        [string]$ExePath,
        [string]$WorkDir
    )

    if (-not (Test-Path -LiteralPath $ExePath)) {
        Write-Host "ERROR: file not found -> $ExePath" -ForegroundColor Red
        exit 1
    }

    Stop-OldInstance

    if (-not (Test-IsAdmin)) {
        Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir -Verb RunAs | Out-Null
    }
    else {
        Start-Process -FilePath $ExePath -WorkingDirectory $WorkDir | Out-Null
    }

    Write-Host 'OK' -ForegroundColor Green
}

function Save-RemoteExe {
    param(
        [string]$Url,
        [string]$TargetPath
    )

    $temp = Join-Path $env:TEMP ("sk_" + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Write-Host 'Downloading SuperKill.exe ...' -ForegroundColor Cyan
        Invoke-WebRequest -Uri $Url -OutFile $temp -UseBasicParsing
        Copy-Item -LiteralPath $temp -Destination $TargetPath -Force
        Write-Host 'Download OK' -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: download failed -> $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "URL: $Url" -ForegroundColor Yellow
        exit 1
    }
    finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

function Restart-AsAdminOnline {
    $cmd = "iex (irm '$ScriptUrl')"
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command',
        $cmd
    ) | Out-Null
}

$localExe = Find-LocalExe

if ($localExe) {
    Start-App -ExePath $localExe -WorkDir (Split-Path -Parent $localExe)
    exit 0
}

if (-not (Test-IsAdmin)) {
    Restart-AsAdminOnline
    exit 0
}

$installDir = Get-InstallFolder
$targetExe = Join-Path $installDir $ExeName
Save-RemoteExe -Url $ExeUrl -TargetPath $targetExe
Start-App -ExePath $targetExe -WorkDir $installDir
