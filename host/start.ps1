# Run from the cloned repo:  cd $HOME\cryax\host ; .\start.ps1
# Hidden (no command prompt):  .\start.ps1 -Hidden
param(
    [switch]$Restart,
    [switch]$Hidden
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".\main.py")) {
    Write-Error "This script must live next to main.py in cryax\host. Do not run it from C:\WINDOWS\system32."
}

function Invoke-Py {
    param([Parameter(ValueFromRemainingArguments = $true)]$PyArgs)
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 @PyArgs
        return
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        & python @PyArgs
        return
    }
    Write-Error "Python 3 is not installed. Install it from https://www.python.org/downloads/ and check 'Add python.exe to PATH'."
}

function Get-ListenPids {
    param([int]$Port)
    $ids = @()
    foreach ($line in (& netstat -ano -p tcp 2>$null)) {
        if ($line -match ":$Port\s+\S+\s+LISTENING\s+(\d+)\s*$") {
            $procId = [int]$Matches[1]
            if ($ids -notcontains $procId) {
                $ids += $procId
            }
        }
    }
    return $ids
}

function Stop-PortHolders {
    param([int]$Port)
    $ids = @(Get-ListenPids -Port $Port)
    foreach ($procId in $ids) {
        Write-Host "Stopping leftover process $procId on port $Port"
        cmd.exe /c "taskkill /PID $procId /T /F >nul 2>&1"
    }
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 200
        if (@(Get-ListenPids -Port $Port).Count -eq 0) {
            return
        }
    }
}

function Test-CryaxHealth {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8787/health" -TimeoutSec 2
        return [bool]$resp.ok
    } catch {
        return $false
    }
}

function Stop-DiscordWorkers {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'cryax_host\.discord_worker' } |
        ForEach-Object {
            Write-Host "Stopping leftover Discord bot $($_.ProcessId)"
            cmd.exe /c "taskkill /PID $($_.ProcessId) /T /F >nul 2>&1"
        }
}

$healthy = Test-CryaxHealth
if ($healthy -and -not $Restart) {
    Write-Host "CONTROL is already running: http://127.0.0.1:8787"
    Write-Host "Open that page. The Discord bot Start button is on the Discord card."
    Write-Host "To stop it and start fresh:  .\start.ps1 -Restart"
    exit 0
}

if ($Restart -or (-not $healthy -and @(Get-ListenPids -Port 8787).Count -gt 0)) {
    Stop-PortHolders -Port 8787
}
Stop-DiscordWorkers

if (-not (Test-Path ".\.venv\Scripts\python.exe")) {
    Invoke-Py -m venv .venv
}

$venvPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$venvPythonw = Join-Path $PSScriptRoot ".venv\Scripts\pythonw.exe"
& $venvPython -m pip install -r (Join-Path $PSScriptRoot "requirements.txt")

$envExample = Join-Path $PSScriptRoot "..\.env.example"
$envFile = Join-Path $PSScriptRoot "..\.env"
if ((Test-Path $envExample) -and -not (Test-Path $envFile)) {
    Copy-Item $envExample $envFile
}

$mainPy = Join-Path $PSScriptRoot "main.py"
if ($Hidden) {
    $exe = $venvPython
    if (Test-Path $venvPythonw) {
        $exe = $venvPythonw
    }
    Start-Process -FilePath $exe -ArgumentList @($mainPy) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
    Write-Host "Cryax host is running in the background (no command prompt)."
    Write-Host "CONTROL: http://127.0.0.1:8787"
    Write-Host "Turn on Start with Windows there so it comes back after reboot."
    exit 0
}

Write-Host "CONTROL dashboard: http://127.0.0.1:8787  (Ctrl+C to stop, or use .\start.ps1 -Hidden)"
& $venvPython $mainPy
