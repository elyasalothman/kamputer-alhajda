#Requires -Version 5.1
<#
.SYNOPSIS
  تثبيت «الهجدة» كجهاز افتراضي على ويندوز بخطوة واحدة — بدون فلاشة USB.
  One-step install of Alhajda OS as a virtual machine on Windows (no USB stick needed).

.DESCRIPTION
  1. Checks / enables Hyper-V (Windows 10/11 Pro, Enterprise, Education).
     On Windows Home (no Hyper-V) it falls back to VirtualBox if installed (or offers to install it with winget).
  2. Downloads the newest "os-v*" image from this repo's GitHub Releases (re-joins .partNN pieces,
     verifies SHA256).
  3. Creates and starts the VM.
  Nothing on your physical disk partitions is changed.

.EXAMPLE
  # أسهل طريقة — سطر واحد في PowerShell (يطلب صلاحيات المسؤول تلقائياً):
  irm https://alhajda.com/os.ps1 | iex
  # أو شغّل الملف AlhajdaSetup.cmd من صفحة https://alhajda.com/os

.EXAMPLE
  .\install-alhajda-vm.ps1 -Update    # يعرض آخر إصدار ويحدّث ملفات المثبّت فقط — لا يلمس الجهاز الافتراضي ولا بياناتك
  .\install-alhajda-vm.ps1 -DryRun    # فحص فقط: يكتشف Hyper-V/VirtualBox والإصدار والملفات دون أي تغيير

.EXAMPLE
  .\install-alhajda-vm.ps1 -MemoryGB 6 -CPUCount 4 -DiskGB 60
  .\install-alhajda-vm.ps1 -LocalImage D:\Downloads\alhajda-1.0.0-hyperv.vhdx.zip
#>
[CmdletBinding()]
param(
  [string]$VMName = 'Alhajda',
  [ValidateRange(2, 64)][int]$MemoryGB = 4,
  [ValidateRange(1, 32)][int]$CPUCount = 2,
  [ValidateRange(20, 2000)][int]$DiskGB = 40,
  [string]$Tag = '',
  [string]$InstallDir = 'C:\Alhajda-VM',
  [string]$Repo = 'elyasalothman/kamputer-alhajda',
  [ValidateSet('Auto', 'HyperV', 'VirtualBox')][string]$Hypervisor = 'Auto',
  [string]$LocalImage = '',
  [switch]$NoStart,
  [switch]$Force,
  [switch]$Update,
  [switch]$DryRun,
  [switch]$Pause
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

trap {
  Write-Host ''
  Write-Host ("✖ خطأ / Error: " + $_.Exception.Message) -ForegroundColor Red
  if ($Pause) { Read-Host 'اضغط Enter للإغلاق / Press Enter to close' | Out-Null }
  exit 1
}

function Say([string]$Ar, [string]$En = '') {
  Write-Host ("» " + $Ar) -ForegroundColor Cyan
  if ($En) { Write-Host ("  " + $En) -ForegroundColor DarkGray }
}
function Warn([string]$Ar, [string]$En = '') {
  Write-Host ("! " + $Ar) -ForegroundColor Yellow
  if ($En) { Write-Host ("  " + $En) -ForegroundColor DarkYellow }
}
function Ask([string]$Question) {
  $a = Read-Host ($Question + ' [Y/N]')
  return ($a -match '^(y|yes|نعم|ن)$')
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ForwardArgs {
  $list = @()
  foreach ($entry in $script:BoundParams.GetEnumerator()) {
    $v = $entry.Value
    if ($v -is [System.Management.Automation.SwitchParameter]) { if ($v.IsPresent) { $list += "-$($entry.Key)" } }
    else { $list += "-$($entry.Key)"; $list += ('"{0}"' -f $v) }
  }
  return $list
}
$script:BoundParams = $PSBoundParameters
function Exit-Script([int]$Code = 0) {
  if ($Pause) { Read-Host 'اضغط Enter للإغلاق / Press Enter to close' | Out-Null }
  exit $Code
}

# ---------------------------------------------------------------- elevation
if (-not (Test-Admin) -and -not $DryRun) {
  if (-not $PSCommandPath) {
    throw 'شغّل PowerShell كمسؤول (Run as Administrator) ثم أعد تشغيل السكربت. / Please run from an elevated PowerShell.'
  }
  Say 'يحتاج السكربت صلاحيات المسؤول… سيُطلب منك الموافقة.' 'Re-launching as Administrator…'
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath)) + (Get-ForwardArgs)
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  return
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$DownloadDir = Join-Path $InstallDir 'download'
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
$ghHeaders = @{ 'User-Agent' = 'alhajda-vm-installer'; 'Accept' = 'application/vnd.github+json' }
$InstalledFile = Join-Path $InstallDir 'installed-release.txt'

# ---------------------------------------------------------------- -Update
# التحديثات الفعلية للنظام تتم من داخل «الهجدة» نفسه (أداة «تحديث الهجدة» + تحديثات أوبونتو الأمنية التلقائية).
# هذا الوضع لا يلمس الجهاز الافتراضي ولا قرصه ولا بياناتك: يعرض الإصدار ويحدّث ملفات المثبّت في $InstallDir فقط.
if ($Update) {
  $rels = Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases?per_page=50"
  $latest = $rels | Where-Object { $_.tag_name -like 'os-v*' -and -not $_.draft } | Select-Object -First 1
  $installed = if (Test-Path $InstalledFile) { (Get-Content $InstalledFile -TotalCount 1).Trim() } else { '' }
  if (-not $installed) { $installed = '(غير معروف / unknown)' }
  Say ("الإصدار المثبّت بهذا السكربت: {0} — أحدث إصدار: {1}" -f $installed, $latest.tag_name) $latest.html_url
  foreach ($n in @('install-alhajda-vm.ps1', 'AlhajdaSetup.cmd')) {
    $a = $latest.assets | Where-Object { $_.name -eq $n } | Select-Object -First 1
    if ($a) { Invoke-WebRequest -UseBasicParsing -Uri $a.browser_download_url -OutFile (Join-Path $InstallDir $n); Say "تم تحديث $n في $InstallDir" 'installer file refreshed' }
  }
  Say 'لتحديث النظام نفسه: داخل «الهجدة» افتح «تحديث الهجدة» من سطح المكتب أو القائمة (أو الأمر alhajda-update). يعمل تلقائياً كل أسبوع أيضاً.' 'Inside Alhajda run "alhajda-update" (also runs weekly). Your VM and files are untouched.'
  Warn 'لتركيب صورة جديدة كلياً بدلاً من التحديث: أعد التشغيل بـ -Force (يحذف الجهاز الحالي وبياناته!).' 'Fresh image instead: re-run with -Force (DELETES the current VM and its data).'
  Exit-Script 0
}

# ---------------------------------------------------------------- hypervisor detection
function Get-HyperVState {
  try { $f = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All' -ErrorAction Stop }
  catch { return 'Unavailable' }
  if (-not $f) { return 'Unavailable' }
  if ($f.State -eq 'Enabled') {
    if ((Get-Command New-VM -ErrorAction SilentlyContinue) -and (Get-Service vmms -ErrorAction SilentlyContinue)) { return 'Enabled' }
    return 'NeedsReboot'
  }
  return 'Disabled'
}

function Find-VBoxManage {
  $c = @()
  if ($env:VBOX_MSI_INSTALL_PATH) { $c += (Join-Path $env:VBOX_MSI_INSTALL_PATH 'VBoxManage.exe') }
  if ($env:VBOX_INSTALL_PATH) { $c += (Join-Path $env:VBOX_INSTALL_PATH 'VBoxManage.exe') }
  $c += (Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe')
  foreach ($p in $c) { if ($p -and (Test-Path $p)) { return $p } }
  $cmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Register-ResumeAfterReboot {
  $self = Join-Path $InstallDir 'install-alhajda-vm.ps1'
  if ($PSCommandPath -and ($PSCommandPath -ne $self)) { Copy-Item -Force $PSCommandPath $self }
  $cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f $self, ((Get-ForwardArgs) -join ' ')
  New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'AlhajdaVM' -Value $cmd -PropertyType String -Force | Out-Null
}

$hv = Get-HyperVState
$choice = $Hypervisor
if ($choice -eq 'Auto') {
  if ($hv -in @('Enabled', 'Disabled', 'NeedsReboot')) { $choice = 'HyperV' }
  else { $choice = 'VirtualBox' }
}
Say ("حالة Hyper-V: {0} — سيتم استخدام: {1}" -f $hv, $choice) ("Hyper-V state: $hv; using: $choice")

# ---------------------------------------------------------------- -DryRun (no changes at all)
if ($DryRun) {
  $sfx = if ($choice -eq 'HyperV') { '-hyperv.vhdx.zip' } else { '-virtualbox.vmdk' }
  if ($Tag) { $r = Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" }
  else {
    # assign first: Windows PowerShell 5.1 passes a JSON array down the pipeline as ONE object
    $all = Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases?per_page=50"
    $r = $all | Where-Object { $_.tag_name -like 'os-v*' -and -not $_.draft } | Select-Object -First 1
  }
  if (-not $r) { throw 'no os-v* release found' }
  $files = @($r.assets | Where-Object { $_.name -like "*$sfx" -or $_.name -like "*$sfx.part*" })
  $sums = $r.assets | Where-Object { $_.name -eq 'SHA256SUMS' }
  Write-Host ("ALHAJDA_DRYRUN release={0} hypervisor={1} hv_state={2} image_files={3} sha256sums={4} admin={5} ps={6}" -f `
      $r.tag_name, $choice, $hv, $files.Count, [bool]$sums, (Test-Admin), $PSVersionTable.PSVersion)
  $files | ForEach-Object { Write-Host ("  {0}  {1:N2} GB" -f $_.name, ($_.size / 1GB)) }
  if ($files.Count -eq 0 -or -not $sums) { throw 'release is missing image files or SHA256SUMS' }
  Exit-Script 0
}

if ($choice -eq 'HyperV') {
  if ($hv -eq 'Unavailable') { throw 'Hyper-V غير متوفر في هذه النسخة من ويندوز (Home). استخدم -Hypervisor VirtualBox. / Hyper-V is not available on this edition.' }
  if ($hv -eq 'Disabled') {
    Say 'تفعيل Hyper-V… (قد يستغرق دقائق)' 'Enabling Hyper-V…'
    Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All' -All -NoRestart | Out-Null
    $hv = 'NeedsReboot'
  }
  if ($hv -eq 'NeedsReboot') {
    Register-ResumeAfterReboot
    Warn 'تم تفعيل Hyper-V ويجب إعادة تشغيل الجهاز. سيكمل السكربت تلقائياً بعد إعادة التشغيل وتسجيل الدخول.' 'Hyper-V enabled: a restart is required. The script resumes automatically after you sign in again.'
    if (Ask 'إعادة التشغيل الآن؟ / Restart now?') { Restart-Computer -Force }
    return
  }
  $proc = Get-CimInstance Win32_ComputerSystem
  if (-not $proc.HypervisorPresent) {
    Warn 'لا يبدو أن المعالج الافتراضي (Virtualization / VT-x / SVM) مفعّل في BIOS. إن فشل التشغيل فعّله من إعدادات BIOS/UEFI.' 'Hypervisor not running — enable VT-x/AMD-V in firmware setup if the VM fails to start.'
  }
}
else {
  $vbox = Find-VBoxManage
  if (-not $vbox) {
    Warn 'VirtualBox غير مثبت.' 'VirtualBox is not installed.'
    if ((Get-Command winget -ErrorAction SilentlyContinue) -and (Ask 'تثبيت VirtualBox الآن عبر winget؟ / Install VirtualBox with winget now?')) {
      winget install --id Oracle.VirtualBox -e --accept-package-agreements --accept-source-agreements
      $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
      $vbox = Find-VBoxManage
    }
    if (-not $vbox) { throw 'ثبّت VirtualBox من https://www.virtualbox.org ثم أعد تشغيل السكربت. / Install VirtualBox, then re-run.' }
  }
}

# ---------------------------------------------------------------- download helpers

function Get-AlhajdaRelease {
  if ($Tag) { return Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" }
  $rels = Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases?per_page=50"
  $r = $rels | Where-Object { $_.tag_name -like 'os-v*' -and -not $_.draft } | Select-Object -First 1
  if (-not $r) { throw "لا يوجد إصدار os-v* في https://github.com/$Repo/releases بعد. / No os-v* release found yet." }
  return $r
}

function Save-Url([string]$Url, [string]$Dest) {
  $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
  if (Test-Path $curl) {
    & $curl -L --fail --retry 5 --retry-delay 5 -C - -o $Dest $Url
    if ($LASTEXITCODE -ne 0) { throw "download failed ($LASTEXITCODE): $Url" }
  }
  else {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Dest
  }
}

function Join-Parts([string[]]$Parts, [string]$Dest) {
  $out = [IO.File]::Create($Dest)
  try {
    foreach ($p in $Parts) {
      $in = [IO.File]::OpenRead($p)
      try { $in.CopyTo($out, 8MB) } finally { $in.Dispose() }
    }
  }
  finally { $out.Dispose() }
}

function Get-ReleaseFile($Release, [string]$Suffix) {
  # returns local path of the whole file "<anything><Suffix>" (joins .partNN if split)
  $whole = $Release.assets | Where-Object { $_.name -like "*$Suffix" } | Select-Object -First 1
  $parts = @($Release.assets | Where-Object { $_.name -like "*$Suffix.part*" } | Sort-Object name)
  if (-not $whole -and $parts.Count -eq 0) { throw "asset *$Suffix not found in release $($Release.tag_name)" }
  $name = if ($whole) { $whole.name } else { $parts[0].name -replace '\.part\d+$', '' }
  $dest = Join-Path $DownloadDir $name

  $sums = $Release.assets | Where-Object { $_.name -eq 'SHA256SUMS' } | Select-Object -First 1
  $expected = $null
  if ($sums) {
    $sumFile = Join-Path $DownloadDir 'SHA256SUMS'
    Save-Url $sums.browser_download_url $sumFile
    $line = Get-Content $sumFile | Where-Object { $_ -match ([regex]::Escape($name) + '$') } | Select-Object -First 1
    if ($line) { $expected = ($line -split '\s+')[0].ToLower() }
  }
  if ((Test-Path $dest) -and $expected) {
    if ((Get-FileHash -Algorithm SHA256 $dest).Hash.ToLower() -eq $expected) { Say "الملف موجود مسبقاً ومطابق: $name" 'already downloaded'; return $dest }
  }
  if ($whole) {
    Say ("تحميل {0} ({1:N1} GB)…" -f $name, ($whole.size / 1GB)) 'downloading'
    Save-Url $whole.browser_download_url $dest
  }
  else {
    $local = @()
    foreach ($p in $parts) {
      $pd = Join-Path $DownloadDir $p.name
      Say ("تحميل الجزء {0} ({1:N1} GB)…" -f $p.name, ($p.size / 1GB)) 'downloading part'
      Save-Url $p.browser_download_url $pd
      $local += $pd
    }
    Say 'دمج الأجزاء…' 'joining parts'
    Join-Parts $local $dest
    $local | ForEach-Object { Remove-Item -Force $_ }
  }
  if ($expected) {
    Say 'التحقق من SHA256…' 'verifying checksum'
    $h = (Get-FileHash -Algorithm SHA256 $dest).Hash.ToLower()
    if ($h -ne $expected) { Remove-Item -Force $dest; throw "SHA256 mismatch for $name" }
  }
  else { Warn 'لم يتم العثور على SHA256SUMS — تخطّي التحقق.' 'no checksum available' }
  return $dest
}

function Expand-Zip([string]$Zip, [string]$Dir) {
  Say 'فك الضغط… (قد يستغرق عدة دقائق)' 'extracting'
  $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
  if (Test-Path $tar) {
    & $tar -xf $Zip -C $Dir
    if ($LASTEXITCODE -eq 0) { return }
  }
  Expand-Archive -Force -Path $Zip -DestinationPath $Dir
}

# ---------------------------------------------------------------- get the image
$suffix = if ($choice -eq 'HyperV') { '-hyperv.vhdx.zip' } else { '-virtualbox.vmdk' }
if ($LocalImage) {
  if (-not (Test-Path $LocalImage)) { throw "LocalImage not found: $LocalImage" }
  $img = (Resolve-Path $LocalImage).Path
}
else {
  $rel = Get-AlhajdaRelease
  Say ("الإصدار: {0}" -f $rel.tag_name) $rel.html_url
  $img = Get-ReleaseFile $rel $suffix
  Set-Content -Path $InstalledFile -Value $rel.tag_name -Encoding ASCII
}

# ---------------------------------------------------------------- Hyper-V
if ($choice -eq 'HyperV') {
  Import-Module Hyper-V
  if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    if (-not $Force) { throw "يوجد جهاز افتراضي باسم '$VMName'. استخدم -VMName آخر أو -Force للاستبدال. / VM exists." }
    Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $VMName -Force
  }
  $vmDir = Join-Path $InstallDir $VMName
  New-Item -ItemType Directory -Force -Path $vmDir | Out-Null
  $vhd = Join-Path $vmDir "$VMName.vhdx"
  if (Test-Path $vhd) {
    if (-not $Force) { throw "القرص موجود: $vhd (استخدم -Force) / disk exists" }
    Remove-Item -Force $vhd
  }
  if ($img -like '*.zip') {
    $tmp = Join-Path $DownloadDir 'unzipped'
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Expand-Zip $img $tmp
    $src = Get-ChildItem $tmp -Filter *.vhdx | Select-Object -First 1
    Move-Item -Force $src.FullName $vhd
  }
  else { Copy-Item -Force $img $vhd }

  $target = [int64]$DiskGB * 1GB
  if ((Get-VHD -Path $vhd).Size -lt $target) {
    Say "تكبير القرص إلى $DiskGB GB (يتوسع النظام تلقائياً عند أول إقلاع)" 'resizing VHDX'
    Resize-VHD -Path $vhd -SizeBytes $target
  }

  $switch = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
  if (-not $switch) { $switch = Get-VMSwitch -ErrorAction SilentlyContinue | Select-Object -First 1 }

  Say "إنشاء الجهاز الافتراضي '$VMName'…" 'creating VM (Generation 2, UEFI)'
  $vmArgs = @{ Name = $VMName; Generation = 2; MemoryStartupBytes = ([int64]$MemoryGB * 1GB); VHDPath = $vhd; Path = $InstallDir }
  if ($switch) { $vmArgs.SwitchName = $switch.Name } else { Warn 'لا يوجد محوّل شبكة في Hyper-V؛ سيعمل الجهاز بدون إنترنت.' 'no virtual switch found' }
  New-VM @vmArgs | Out-Null
  Set-VMProcessor -VMName $VMName -Count $CPUCount
  Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
  # Image ships Microsoft-signed shim, but Secure Boot off is the most compatible default.
  Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
  Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false -AutomaticStartAction Nothing
  try { Enable-VMIntegrationService -VMName $VMName -Name 'Guest Service Interface' } catch { }

  if (-not $NoStart) {
    Start-VM -Name $VMName
    Start-Process -FilePath 'vmconnect.exe' -ArgumentList @('localhost', $VMName)
  }
}
# ---------------------------------------------------------------- VirtualBox
else {
  $vbox = Find-VBoxManage
  $existing = & $vbox list vms | Select-String -SimpleMatch ('"{0}"' -f $VMName)
  if ($existing) {
    if (-not $Force) { throw "يوجد جهاز VirtualBox باسم '$VMName'. استخدم -Force. / VM exists." }
    & $vbox controlvm $VMName poweroff 2>$null
    & $vbox unregistervm $VMName --delete
  }
  $vmDir = Join-Path $InstallDir $VMName
  New-Item -ItemType Directory -Force -Path $vmDir | Out-Null
  $vdi = Join-Path $vmDir "$VMName.vdi"
  if (Test-Path $vdi) { Remove-Item -Force $vdi }
  Say 'تحويل القرص إلى VDI…' 'converting disk'
  & $vbox clonemedium disk $img $vdi --format VDI
  if ($LASTEXITCODE -ne 0) { throw 'clonemedium failed' }
  & $vbox modifymedium disk $vdi --resize ([int64]$DiskGB * 1024) | Out-Null

  & $vbox createvm --name $VMName --ostype Ubuntu_64 --register --basefolder $InstallDir | Out-Null
  & $vbox modifyvm $VMName --memory ([int]$MemoryGB * 1024) --cpus $CPUCount --firmware bios `
      --graphicscontroller vmsvga --vram 64 --nic1 nat --rtcuseutc on --clipboard-mode bidirectional --ioapic on
  & $vbox storagectl $VMName --name SATA --add sata --controller IntelAhci --portcount 1
  & $vbox storageattach $VMName --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi
  if (-not $NoStart) { & $vbox startvm $VMName --type gui }
}

Write-Host ''
Say 'تم ✔ — «الهجدة» يعمل الآن في نافذة الجهاز الافتراضي.' 'Done. Alhajda is starting in the VM window.'
Say 'المستخدم: alhajda — كلمة المرور: alhajda (غيّرها من الإعدادات أو بالأمر passwd)' 'user: alhajda / password: alhajda — change it.'
Say 'تبديل لوحة المفاتيح عربي/إنجليزي: Alt+Shift' 'Keyboard layout toggle: Alt+Shift'
Say 'التحديث لاحقاً: داخل «الهجدة» افتح «تحديث الهجدة» (ويعمل تلقائياً أسبوعياً). تحديثات أوبونتو الأمنية تلقائية.' 'Updates: run "Alhajda Update" inside the VM (also automatic weekly).'
Exit-Script 0
