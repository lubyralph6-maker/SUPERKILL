# FASTKILL launcher - works with:
#   powershell -ExecutionPolicy Bypass -File .\FASTKILL.ps1
#   iex (irm 'https://cdn.jsdelivr.net/gh/lubyralph6-maker/FASTKILL@main/FASTKILL.ps1')
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://cdn.jsdelivr.net/gh/lubyralph6-maker/FASTKILL@main/FASTKILL.ps1')"

$ErrorActionPreference = 'Stop'

$exeName = 'FastKill.exe'
$installDir = Join-Path $env:LOCALAPPDATA 'FASTKILL'
$exePath = Join-Path $installDir $exeName
$downloadHeaders = @{
    'User-Agent' = 'FASTKILL-Launcher/1.0 (Windows; PowerShell)'
    'Accept'     = '*/*'
}
$exeUrls = @(
    'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FastKill.exe',
    'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FastKill.exe?download=1'
)

function Write-Status([string]$Text, [string]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory = $true)][string[]]$Urls,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $lastError = $null

    foreach ($url in $Urls) {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Write-Status "Downloading (try $attempt): $url" Cyan
                Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing -Headers $downloadHeaders
                if ((Test-Path -LiteralPath $OutFile) -and ((Get-Item -LiteralPath $OutFile).Length -gt 100000)) {
                    return $true
                }
                Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
                throw 'Downloaded file is missing or too small.'
            }
            catch {
                $lastError = $_
                $msg = $_.Exception.Message
                if ($msg -match '429|Too Many Requests') {
                    $waitSec = 15 * $attempt
                    Write-Status "GitHub rate limit (429). Waiting ${waitSec}s..." Yellow
                    Start-Sleep -Seconds $waitSec
                }
                elseif ($attempt -lt 3) {
                    Start-Sleep -Seconds (5 * $attempt)
                }
            }
        }
    }

    if ($null -ne $lastError) {
        throw $lastError.Exception.Message
    }
    return $false
}

function Get-LocalExeNearScript {
    $roots = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $roots += $PSScriptRoot
    }
    $roots += (Get-Location).Path

    foreach ($root in $roots | Select-Object -Unique) {
        $candidates = @(
            (Join-Path $root $exeName),
            (Join-Path $root 'bin\FastKill.exe'),
            (Join-Path $root 'bin\FASTKILL.exe')
        )
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    return $null
}

function Get-CachedOrDownloadedExe {
    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $exePath) {
        return $exePath
    }

    if (-not (Invoke-DownloadFile -Urls $exeUrls -OutFile $exePath)) {
        throw 'Download failed - FastKill.exe not found after download.'
    }

    Write-Status 'Downloaded' Green
    return $exePath
}

function Resolve-ExePath {
    $local = Get-LocalExeNearScript
    if ($null -ne $local) {
        return $local
    }
    return Get-CachedOrDownloadedExe
}

try {
    $targetExe = Resolve-ExePath
    if ([string]::IsNullOrWhiteSpace($targetExe)) {
        throw 'Could not resolve FastKill.exe path.'
    }

    Write-Status "Using: $targetExe" Green
    Write-Status 'Starting FASTKILL V.1 (Administrator)...' Cyan

    $proc = Start-Process -FilePath $targetExe -Verb RunAs -PassThru
    if ($null -eq $proc) {
        throw 'Start-Process returned null.'
    }

    Start-Sleep -Seconds 2
    if ($proc.HasExited) {
        throw "FastKill closed immediately (exit $($proc.ExitCode)). Run as Administrator and check antivirus exclusion."
    }

    Write-Status 'FASTKILL is running.' Green
    Write-Status 'Finished' Green
}
catch {
    Write-Status "Error: $($_.Exception.Message)" Red
    Write-Status 'If 429: wait 1-2 min and retry, or send friend bin\FastKill.exe directly.' Yellow
}

Write-Host ''
Read-Host 'Press Enter to close'
