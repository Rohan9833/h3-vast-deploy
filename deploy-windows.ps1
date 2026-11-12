$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "MiniMax H3 - Windows launcher" -ForegroundColor Cyan
Write-Host "This launcher uses WSL Ubuntu. It does not run SGLang natively on Windows."
Write-Host ""

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Host "WSL is not installed. Requesting WSL + Ubuntu installation..." -ForegroundColor Yellow
    Write-Host "Windows may ask for Administrator permission. A Windows restart may be required."
    & wsl.exe --install -d Ubuntu
    Write-Host ""
    Write-Host "If installation asks you to restart, restart Windows, open Ubuntu once to create its Linux username/password, then run deploy-windows.bat again."
    exit 0
}

# WSL list output can contain NUL characters depending on Windows/PowerShell version.
$distros = @(& wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
$ubuntu = $distros | Where-Object { $_ -match "^Ubuntu($|[- ])" } | Select-Object -First 1

if (-not $ubuntu) {
    Write-Host "WSL is installed, but no Ubuntu distribution was found." -ForegroundColor Yellow
    Write-Host "Installing Ubuntu now. You may need Administrator permission and a restart."
    & wsl.exe --install -d Ubuntu
    Write-Host ""
    Write-Host "After installation, restart if requested, open Ubuntu once to finish first-time setup, then run deploy-windows.bat again."
    exit 0
}

Write-Host "Using WSL distribution: $ubuntu" -ForegroundColor Green
Write-Host "Project folder: $PSScriptRoot"

# Convert this Windows project path to its Linux /mnt/<drive>/... path.
$linuxPath = (& wsl.exe -d $ubuntu -- wslpath -a "$PSScriptRoot" | Out-String).Trim()
if (-not $linuxPath) {
    throw "Could not convert the project path into a WSL path."
}

# Escape single quotes for the bash command.
$escapedPath = $linuxPath.Replace("'", "'\''")
$bashCommand = "cd '$escapedPath' && git pull --ff-only && bash deploy.sh"

Write-Host ""
Write-Host "Starting the deployment inside WSL Ubuntu..." -ForegroundColor Cyan
Write-Host "Note: this runs on THIS PC, not on your Vast.ai server."
Write-Host "The local PC must independently meet the deployment hardware requirements."
Write-Host ""

& wsl.exe -d $ubuntu -- bash -lc $bashCommand
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Deployment exited with code $exitCode. Review the error above." -ForegroundColor Red
}
exit $exitCode
