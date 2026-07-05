    }
}
function Stop-OldInstance {
    Get-Process -Name 'SuperKill' -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}
# If not admin and no local exe, re-launch this script as admin (for download + run).
$scriptDir = Get-ScriptFolder
$localExe = Find-LocalExe @($scriptDir, $PWD.Path, (Join-Path $scriptDir 'bin'))
if (-not (Test-IsAdmin) -and -not $localExe) {
    $scriptUrl = "$RepoBase/SUPERKILL.ps1"
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-Command', "iex (irm '$scriptUrl')"
    ) | Out-Null
    exit 0
}
if ($localExe) {
    Start-SuperKillApp -ExePath $localExe -WorkDir (Split-Path -Parent $localExe)
    exit 0
}
Write-Host 'ERROR: SuperKill.exe not found next to this script.' -ForegroundColor Red
Write-Host "Put SuperKill.exe in: $scriptDir" -ForegroundColor Yellow
exit 1
$installDir = Get-InstallFolder
$targetExe = Join-Path $installDir $ExeName
if (-not (Test-Path -LiteralPath $targetExe)) {
    Download-Exe -Url $ExeUrl -TargetPath $targetExe
} else {
    try {
        Download-Exe -Url $ExeUrl -TargetPath $targetExe
    } catch {
        Write-Host 'Update skipped, using existing SuperKill.exe' -ForegroundColor Yellow
    }
}
Start-SuperKillApp -ExePath $targetExe -WorkDir $installDir
