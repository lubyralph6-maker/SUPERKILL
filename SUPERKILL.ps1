# GitHub: FASTKILL.ps1 + FastKill.exe (same folder, main branch)
# iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    if (-not (Test-Path 'HKCU:\Software\Microsoft\PowerShell\PSReadLine')) {
        New-Item 'HKCU:\Software\Microsoft\PowerShell\PSReadLine' -Force | Out-Null
    }
    Set-ItemProperty 'HKCU:\Software\Microsoft\PowerShell\PSReadLine' HistorySaveStyle 2 -Type DWord -Force
    Import-Module PSReadLine -ErrorAction SilentlyContinue | Out-Null
    Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction SilentlyContinue
} catch {}

$dir = Join-Path $env:LOCALAPPDATA 'FASTKILL'
$exe = Join-Path $dir 'FastKill.exe'
$tmp = Join-Path $dir 'FastKill.download'
$marker = Join-Path $dir '.ps1_redownload'
$urls = @(
    'https://github.com/lubyralph6-maker/FASTKILL/raw/main/FastKill.exe',
    'https://ghproxy.net/https://github.com/lubyralph6-maker/FASTKILL/raw/main/FastKill.exe',
    'https://ghproxy.net/https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FastKill.exe',
    'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FastKill.exe'
)
$hdr = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FASTKILL/1.1'
    'Accept'     = '*/*'
}

function Write-Fk([string]$Text, [string]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Test-FkExe([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $f = Get-Item -LiteralPath $Path
        if ($f.Length -lt 4MB) { return $false }
        $b = [IO.File]::ReadAllBytes($Path)
        if ($b.Length -lt 512) { return $false }
        if ([Text.Encoding]::ASCII.GetString($b, 0, 2) -ne 'MZ') { return $false }
        $o = [BitConverter]::ToInt32($b, 0x3C)
        if ($o -lt 0 -or ($o + 0x200) -gt $b.Length) { return $false }
        if ([Text.Encoding]::ASCII.GetString($b, $o, 4) -ne "PE`0`0") { return $false }
        return ([BitConverter]::ToUInt16($b, $o + 4) -eq 0x8664)
    } catch {
        return $false
    }
}

function Clear-FkCache {
    foreach ($p in @($exe, $tmp, $marker)) {
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-FkDownload {
    param([string]$Url, [string]$OutFile)

    $wc = New-Object System.Net.WebClient
    foreach ($key in $hdr.Keys) { $wc.Headers[$key] = $hdr[$key] }
    $wc.DownloadFile($Url, $OutFile)
}

function Get-FkExe {
    foreach ($local in @(
        (Join-Path $PSScriptRoot 'bin\FastKill.exe'),
        (Join-Path $PSScriptRoot 'FastKill.exe'),
        (Join-Path (Get-Location) 'bin\FastKill.exe'),
        (Join-Path (Get-Location) 'FastKill.exe')
    )) {
        if (Test-FkExe $local) {
            Write-Fk "Using local: $local" Green
            return (Resolve-Path -LiteralPath $local).Path
        }
    }

    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $marker) { Clear-FkCache }
    if ((Test-Path -LiteralPath $exe) -and -not (Test-FkExe $exe)) { Clear-FkCache }
    if ((Test-Path -LiteralPath $exe) -and (Test-FkExe $exe)) {
        Write-Fk "Using cache: $exe" Green
        return $exe
    }

    $lastError = 'Download failed'
    foreach ($url in $urls) {
        foreach ($try in 1..5) {
            try {
                Write-Fk "Download ($try/5): $url" Cyan
                if (Test-Path -LiteralPath $tmp) {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                }

                try {
                    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers $hdr -TimeoutSec 120
                } catch {
                    Invoke-FkDownload -Url $url -OutFile $tmp
                }

                if (-not (Test-FkExe $tmp)) {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                    throw 'Downloaded file is not a valid 64-bit exe'
                }

                if (Test-Path -LiteralPath $exe) {
                    Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
                }
                Move-Item -LiteralPath $tmp -Destination $exe -Force
                if (Test-Path -LiteralPath $marker) {
                    Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
                }

                Write-Fk "Downloaded OK ($((Get-Item -LiteralPath $exe).Length) bytes)" Green
                return $exe
            } catch {
                $lastError = $_.Exception.Message
                if ($lastError -match '429|Too Many Requests') {
                    $wait = 20 * $try
                    Write-Fk "Rate limit 429 - wait ${wait}s..." Yellow
                    Start-Sleep -Seconds $wait
                } else {
                    Write-Fk "Retry: $lastError" Yellow
                    Start-Sleep -Seconds (8 * $try)
                }
            }
        }
    }

    throw $lastError
}

try {
    $path = Get-FkExe
    Write-Fk 'Starting FASTKILL (Administrator)...' Cyan
    $proc = Start-Process -FilePath $path -Verb RunAs -PassThru
    if ($null -eq $proc) { throw 'RunAs failed - click Yes on UAC' }
    Start-Sleep -Seconds 2
    if ($proc.HasExited) { throw "FastKill closed immediately (exit $($proc.ExitCode))" }
    Write-Fk 'FASTKILL running' Green
}
catch {
    Write-Fk "Error: $($_.Exception.Message)" Red
    Write-Fk 'Tip: wait 2 min and run same command again' Yellow
}
