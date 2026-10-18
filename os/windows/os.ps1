# Alhajda OS - one-line installer (bootstrap)
#
#   irm https://alhajda.com/os.ps1 | iex
#
# Downloads install-alhajda-vm.ps1 from the newest os-v* GitHub release (falls back to the repo's
# main branch), then runs it as Administrator (asks for UAC approval when needed).
# Extra options: set $env:ALHAJDA_ARGS first, e.g.  $env:ALHAJDA_ARGS='-MemoryGB 6 -DiskGB 80'
#   or:  & ([scriptblock]::Create((irm https://alhajda.com/os.ps1))) -Update
# This file is ASCII on purpose: the web server sends it as application/octet-stream and
# Windows PowerShell 5.1 would mangle non-ASCII text. Arabic messages come from the installer itself.
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

  $repo = 'elyasalothman/kamputer-alhajda'
  $fwd = @()
  if ($env:ALHAJDA_ARGS) { $fwd += ($env:ALHAJDA_ARGS -split '\s+' | Where-Object { $_ }) }
  $fwd += $args

  Write-Host ''
  Write-Host '  Alhajda OS setup  -  alhajda.com/os' -ForegroundColor Cyan
  Write-Host ''

  $dir = Join-Path $env:TEMP 'alhajda-setup'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $dest = Join-Path $dir 'install-alhajda-vm.ps1'
  $hdr = @{ 'User-Agent' = 'alhajda-os-bootstrap'; 'Accept' = 'application/vnd.github+json' }
  $url = $null
  try {
    $rels = Invoke-RestMethod -UseBasicParsing -Headers $hdr -Uri "https://api.github.com/repos/$repo/releases?per_page=30"
    foreach ($r in $rels) {
      if ($r.draft -or ($r.tag_name -notlike 'os-v*')) { continue }
      $a = $r.assets | Where-Object { $_.name -eq 'install-alhajda-vm.ps1' } | Select-Object -First 1
      if ($a) { $url = $a.browser_download_url; Write-Host "  release: $($r.tag_name)"; break }
    }
  } catch { Write-Host "  (GitHub API not reachable: $($_.Exception.Message))" -ForegroundColor DarkYellow }
  if (-not $url) { $url = "https://raw.githubusercontent.com/$repo/main/os/windows/install-alhajda-vm.ps1" }

  Write-Host "  downloading installer: $url"
  Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent' = 'alhajda-os-bootstrap' } -Uri $url -OutFile $dest
  try { Unblock-File -Path $dest } catch { }

  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $isAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

  if ($isAdmin) {
    & $ps -NoProfile -ExecutionPolicy Bypass -File $dest @fwd
    if ($LASTEXITCODE) { Write-Host "  installer exited with code $LASTEXITCODE" -ForegroundColor Yellow }
  }
  else {
    Write-Host '  Administrator rights are needed - approve the Windows prompt (UAC).' -ForegroundColor Yellow
    Write-Host '  The setup continues in a new window.'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $dest)) + ($fwd | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } })
    if ($argList -notcontains '-Pause') { $argList += '-Pause' }
    try { Start-Process -FilePath $ps -Verb RunAs -ArgumentList $argList }
    catch { Write-Host '  Cancelled: setup needs Administrator approval. Run the command again and choose Yes.' -ForegroundColor Red }
  }
} @args
