# Replace the live 3.0 typed /loader with the Lua 5.1 bootstrap + desugared /script.lua.
# From repo root or this folder:
#   cd $HOME\scorp
#   git pull
#   .\host\worker\deploy.ps1
# Then paste:
#   loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$rev = $null
try { $rev = (git rev-parse --short HEAD 2>$null) } catch { }
if ($rev) {
    Write-Host "Deploying git $rev"
}

$workerJs = Join-Path $PWD "host\worker\src\worker.js"
if (-not (Test-Path $workerJs)) {
    Write-Error "worker.js missing. Run this from a clone of x9ksa/scorp, not an old copy."
}
$workerSrc = Get-Content $workerJs -Raw
if ($workerSrc -notmatch "Scorp loader \(plain Lua\)") {
    Write-Error @"
This clone is still the old Worker (typed 3.0 /loader).
In PowerShell:

  cd `$HOME\scorp
  git fetch origin
  git pull origin cursor/fix-discord-500-f23d
  .\host\worker\deploy.ps1
"@
}
if (-not ([string]$workerSrc).Contains('string.sub(src, 1, 200)')) {
    Write-Error @"
This clone still has the old /loader HTML check.
git fetch origin
git pull origin cursor/fix-discord-500-f23d
then re-run this script.
"@
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is required (npx). Install LTS from https://nodejs.org/ and reopen PowerShell."
}

Write-Host "Logging into Cloudflare if needed (browser window)..."
Write-Host "Use the Cloudflare account that owns scorp-api.scorpontop.workers.dev"
npx --yes wrangler@4 login
npx --yes wrangler@4 deploy

$loaderUrl = "https://scorp-api.scorpontop.workers.dev/loader"
Write-Host ""
Write-Host "Checking $loaderUrl ..."
try {
    $body = (Invoke-WebRequest -Uri $loaderUrl -UseBasicParsing -TimeoutSec 30).Content
} catch {
    Write-Error "Deploy ran, but $loaderUrl could not be fetched: $_"
}

if ($body -match "type TabId" -or $body -match "--!strict") {
    Write-Error @"
Still the old 3.0 typed script. Wrangler did not update this hostname.

Log into the SAME Cloudflare account that owns scorpontop.workers.dev.
In the dashboard: Workers & Pages -> scorp-api -> Deployments (the new one should be there).
If GitHub connected Cloudflare, grant the Cloudflare GitHub App access to private repo x9ksa/scorp.
"@
}
if ($body -notmatch "Scorp loader") {
    Write-Error "/loader is not the plain-Lua bootstrap yet. Re-run deploy while logged into the scorpontop Cloudflare account."
}
$body = [string]$body
if (-not $body.Contains('string.sub(src, 1, 200)')) {
    Write-Error @"
/loader is still the old HTML check. It throws download failed because
/script.lua contains the text <html inside Lua source.

git pull, then re-run this script.
"@
}

$scriptUrl = "https://scorp-api.scorpontop.workers.dev/script.lua"
Write-Host "Checking $scriptUrl ..."
try {
    $script = (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing -TimeoutSec 60).Content
} catch {
    Write-Error "Deploy ran, but $scriptUrl could not be fetched: $_"
}
$script = [string]$script
if ($script.Contains('(env).ScorpClient') -or $script.Contains('(env ).ScorpClient') -or $script.Contains('(env ::')) {
    Write-Error @"
/script.lua still has leftover (env).ScorpClient type-cast fields.
Luau loadstring can fail with:
  Ambiguous syntax: this looks like an argument list for a function call...

git pull, then re-run this script so the Worker gets the assignment rewrite.
"@
}
if ($script -notmatch "env.ScorpClientEpoch = nextEpoch") {
    Write-Error "/script.lua is missing the Lua 5.1-safe epoch assignment. git pull and re-run deploy."
}
if ($script -notmatch 'local SCRIPT_VERSION = "3.14"') {
    Write-Error "/script.lua is still an old client (want 3.14). git pull origin main and re-run this script."
}
if ($script.Contains('<html') -or $script.Contains('<!DOCTYPE')) {
    Write-Error @"
/script.lua still contains <html, so the live /loader will throw download failed.

git fetch origin
git pull origin cursor/fix-discord-500-f23d
then re-run this script.
"@
}

Write-Host "OK: /loader is Lua 5.1 bootstrap (no type TabId)."
Write-Host "OK: /script.lua has no ambiguous (env) statements."
Write-Host "Paste this in your executor:"
Write-Host '  loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()'
Write-Host "Set WORKER_BASE_URL=https://scorp-api.scorpontop.workers.dev in .env"
Write-Host "Nametags on this PC still use http://127.0.0.1:8787 - start the host with .\host\start.ps1 -Hidden"
