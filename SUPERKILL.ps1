param(
    [string]$u = 'https://raw.githubusercontent.com/lubyralph6-maker/RANVYX.EXE/main/SUPERKILL.exe',
    [string]$p = '',
    [string]$s = 'https://raw.githubusercontent.com/lubyralph6-maker/RANVYX.EXE/main/SuperKill.ps1'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$exeName = 'SUPERKILL.exe'
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$localExe = Join-Path $scriptDir $exeName

function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin) -and -not (Test-Path -LiteralPath $localExe)) {
    $ue = $u.Replace("'", "''"); $pe = $p.Replace("'", "''"); $se = $s.Replace("'", "''")
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"`$u='$ue'; `$p='$pe'; iex (irm '$se')`""
    exit
}

if (Test-Path -LiteralPath $localExe) {
    if (-not (Test-IsAdmin)) {
        Start-Process -FilePath $localExe -Verb RunAs -WorkingDirectory $scriptDir
    } else {
        Get-Process SuperKill -EA 0 | Stop-Process -Force -EA 0
        Start-Process -FilePath $localExe -WorkingDirectory $scriptDir
    }
    Write-Host 'OK'
    exit
}

$t = if ($p -and (Test-Path $p)) { $p }
     elseif ($p) { (New-Item -ItemType Directory -Force -Path $p).FullName }
     else { (New-Item -ItemType Directory -Force -Path (Join-Path $env:LOCALAPPDATA 'SUPERKILL')).FullName }

$target = Join-Path $t $exeName
Get-Process SuperKill -EA 0 | Stop-Process -Force -EA 0

$f = Join-Path $env:TEMP ('sk_' + [guid]::NewGuid().ToString('N') + '.tmp')
Invoke-WebRequest $u -OutFile $f -UseBasicParsing
Copy-Item $f $target -Force
Remove-Item $f -Force -EA 0

if (-not (Test-IsAdmin)) {
    Start-Process -FilePath $target -Verb RunAs -WorkingDirectory $t
} else {
    Start-Process -FilePath $target -WorkingDirectory $t
}

Write-Host 'OK'
