# Installs the named Cloudflare tunnel as a Windows service (no command prompt).
# MUST be Run as Administrator - the service control manager rejects a normal PowerShell.
#
# Right-click PowerShell -> Run as administrator, then:
#   cd $HOME\cryax\host
#   .\install-tunnel.ps1
# or paste the token from the Cloudflare dashboard:
#   .\install-tunnel.ps1 eyJ...
param(
    [Parameter(Position = 0)]
    [string]$Token
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Access denied: Windows will not install a service from a normal PowerShell window."
    Write-Host ""
    Write-Host "1. Close this window."
    Write-Host "2. Start menu -> PowerShell -> right-click -> Run as administrator"
    Write-Host "3. cd $HOME\cryax\host"
    Write-Host "4. .\install-tunnel.ps1"
    Write-Host ""
    Write-Host "If Cloudflare gave you a one-liner, run THAT in the Administrator window instead:"
    Write-Host "  cloudflared.exe service install <token>"
    exit 1
}

function Read-EnvToken {
    foreach ($envPath in @((Join-Path $PSScriptRoot "..\.env"), (Join-Path $PSScriptRoot ".env"))) {
        if (-not (Test-Path $envPath)) {
            continue
        }
        foreach ($line in Get-Content $envPath) {
            if ($line -match '^\s*CLOUDFLARE_TUNNEL_TOKEN\s*=\s*(.+)\s*$') {
                $value = $Matches[1].Trim().Trim("'").Trim('"')
                if ($value) {
                    return $value
                }
            }
        }
    }
    return ""
}

if (-not $Token) {
    $Token = Read-EnvToken
}
if (-not $Token) {
    Write-Error "No tunnel token. Pass it as the first argument, or set CLOUDFLARE_TUNNEL_TOKEN in .env."
}

$cloudflared = $null
foreach ($name in @("cloudflared.exe", "cloudflared")) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        $cloudflared = $cmd.Source
        break
    }
}
if (-not $cloudflared) {
    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles "cloudflared\cloudflared.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "cloudflared\cloudflared.exe"),
        (Join-Path $env:LOCALAPPDATA "cloudflared\cloudflared.exe")
    )) {
        if ($candidate -and (Test-Path $candidate)) {
            $cloudflared = $candidate
            break
        }
    }
}
if (-not $cloudflared) {
    Write-Error "cloudflared.exe not found. Install it, then run this script again from Administrator PowerShell."
}

Write-Host "Installing cloudflared Windows service from $cloudflared"
cmd.exe /c "`"$cloudflared`" service uninstall >nul 2>&1"
& $cloudflared service install $Token
if ($LASTEXITCODE -ne 0) {
    Write-Error "cloudflared service install failed (exit $LASTEXITCODE)."
}

$svc = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne "Running") {
    Start-Service cloudflared
    $svc.Refresh()
}
if ($svc) {
    Write-Host "cloudflared service is $($svc.Status). It will start with Windows - no extra command prompt."
} else {
    Write-Host "Service install finished. Reboot if Get-Service cloudflared is missing."
}
Write-Host "Set PUBLIC_BASE_URL in .env to your hostname (https://cryax.yourdomain.com), then:"
Write-Host "  cd $HOME\cryax\host ; .\start.ps1 -Hidden"
Write-Host "Leave AUTO_START_TUNNEL=0 so CONTROL does not start a second tunnel."
