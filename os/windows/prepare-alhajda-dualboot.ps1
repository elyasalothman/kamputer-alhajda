#Requires -Version 5.1
<#
.SYNOPSIS
  [متقدّم / خطِر] تجهيز إقلاع «الهجدة» من القرص الداخلي بدون فلاشة (ISO على قسم ويندوز + GRUB loopback).
  [ADVANCED / RISKY] Prepare booting Alhajda from the internal disk without a USB stick.

.DESCRIPTION
  This script ONLY:
    * checks the PC (UEFI, BitLocker, Fast Startup, free space),
    * downloads the Alhajda live ISO to  <Drive>:\alhajda\alhajda.iso  (joins .partNN, verifies SHA256),
    * writes a ready-to-paste GRUB menu entry to  <Drive>:\alhajda\grub2win-alhajda-entry.cfg.
  It does NOT repartition, format, resize, or change the Windows Boot Manager.
  To actually get a boot menu you install Grub2Win yourself (https://sourceforge.net/projects/grub2win/)
  and add the generated entry as a custom entry. See os/docs/DUALBOOT-ar.md.

  ⚠️ قبل أي شيء: خذ نسخة احتياطية كاملة، واحفظ مفتاح استرداد BitLocker إن كان مفعّلاً.

.EXAMPLE
  .\prepare-alhajda-dualboot.ps1 -IUnderstandTheRisk
  .\prepare-alhajda-dualboot.ps1 -Drive D -IUnderstandTheRisk -DisableFastStartup
#>
[CmdletBinding()]
param(
  [ValidatePattern('^[A-Za-z]$')][string]$Drive = 'C',
  [string]$Tag = '',
  [string]$Repo = 'elyasalothman/kamputer-alhajda',
  [string]$LocalIso = '',
  [switch]$DisableFastStartup,
  [switch]$IUnderstandTheRisk
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

function Say([string]$Ar, [string]$En = '') { Write-Host ("» " + $Ar) -ForegroundColor Cyan; if ($En) { Write-Host ("  " + $En) -ForegroundColor DarkGray } }
function Warn([string]$Ar, [string]$En = '') { Write-Host ("! " + $Ar) -ForegroundColor Yellow; if ($En) { Write-Host ("  " + $En) -ForegroundColor DarkYellow } }

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'شغّل PowerShell كمسؤول. / Run from an elevated (Administrator) PowerShell.'
}

Write-Host ''
Write-Host '==================================================================' -ForegroundColor Red
Write-Host ' ⚠️  مسار متقدّم وخطِر — الإقلاع المزدوج من القرص الداخلي' -ForegroundColor Red
Write-Host '    • خذ نسخة احتياطية كاملة لملفاتك (أو صورة نظام) قبل المتابعة.' -ForegroundColor Red
Write-Host '    • إن كان BitLocker مفعّلاً احفظ مفتاح الاسترداد خارج الجهاز.' -ForegroundColor Red
Write-Host '    • هذا السكربت لا يغيّر الأقسام ولا مدير إقلاع ويندوز.' -ForegroundColor Red
Write-Host '    • تثبيت Grub2Win وتعديل الإقلاع خطوة يدوية تتحمّل مسؤوليتها.' -ForegroundColor Red
Write-Host ' ADVANCED/RISKY. Back up first. This script never repartitions anything.' -ForegroundColor Red
Write-Host '==================================================================' -ForegroundColor Red
if (-not $IUnderstandTheRisk) {
  $a = Read-Host 'اكتب  YES  للمتابعة / type YES to continue'
  if ($a -ne 'YES') { Say 'تم الإلغاء.' 'cancelled'; return }
}

# ---------------------------------------------------------------- checks
$problems = 0
$fw = $env:firmware_type
if (-not $fw) { try { Confirm-SecureBootUEFI | Out-Null; $fw = 'UEFI' } catch [System.PlatformNotSupportedException] { $fw = 'Legacy' } catch { $fw = 'UEFI' } }
Say "نوع الإقلاع: $fw" "firmware: $fw"
if ($fw -ne 'UEFI') { Warn 'الجهاز يعمل بوضع Legacy BIOS. Grub2Win يدعمه، لكن هذه الإرشادات مكتوبة لـ UEFI.' 'Legacy BIOS detected.' }

try {
  $sb = Confirm-SecureBootUEFI
  if ($sb) { Warn 'Secure Boot مفعّل. Grub2Win قد يتطلب تعطيله من إعدادات UEFI.' 'Secure Boot is ON — Grub2Win usually needs it OFF.' }
} catch { }

$vol = "$($Drive.ToUpper()):"
try {
  $bl = Get-BitLockerVolume -MountPoint $vol -ErrorAction Stop
  if ($bl.ProtectionStatus -eq 'On' -or $bl.VolumeStatus -ne 'FullyDecrypted') {
    Warn "BitLocker مفعّل على $vol — GRUB لا يستطيع قراءة ISO من قسم مشفّر." "BitLocker is active on $vol; GRUB cannot read an ISO there."
    Warn 'الحل: استخدم -Drive لقسم بيانات غير مشفّر (مثل D)، أو أوقف التشفير بنفسك بعد حفظ مفتاح الاسترداد.' 'Use -Drive <unencrypted data partition>.'
    $problems++
  }
} catch { Say 'BitLocker: غير متاح/غير مفعّل' 'BitLocker not active or not available' }

$hiber = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
if ($hiber -eq 1) {
  if ($DisableFastStartup) {
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0
    Say 'تم تعطيل Fast Startup (التشغيل السريع).' 'Fast Startup disabled.'
  }
  else { Warn 'Fast Startup مفعّل — يُفضّل تعطيله (أعد التشغيل بالخيار -DisableFastStartup).' 'Fast Startup is ON; re-run with -DisableFastStartup.' }
}

$psd = Get-PSDrive -Name $Drive.ToUpper()
$freeGB = [math]::Round($psd.Free / 1GB, 1)
Say "المساحة الحرة على ${vol}: $freeGB GB" 'free space'
if ($psd.Free -lt 8GB) { Warn 'تحتاج 8 GB حرة على الأقل.' 'need >= 8 GB free'; $problems++ }

$fs = (Get-Volume -DriveLetter $Drive.ToUpper()).FileSystem
if ($fs -notin @('NTFS', 'FAT32', 'exFAT')) { Warn "نظام الملفات $fs غير مدعوم." "filesystem $fs unsupported"; $problems++ }

if ($problems -gt 0) { throw "توقّف: يوجد $problems مشكلة يجب حلها أولاً. / Stopped: fix the issues above first." }

# ---------------------------------------------------------------- download ISO
$dir = Join-Path $vol 'alhajda'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$iso = Join-Path $dir 'alhajda.iso'
$ghHeaders = @{ 'User-Agent' = 'alhajda-dualboot'; 'Accept' = 'application/vnd.github+json' }

function Save-Url([string]$Url, [string]$Dest) {
  $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
  if (Test-Path $curl) { & $curl -L --fail --retry 5 -C - -o $Dest $Url; if ($LASTEXITCODE -ne 0) { throw "download failed: $Url" } }
  else { Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Dest }
}

if ($LocalIso) {
  Copy-Item -Force $LocalIso $iso
}
else {
  if ($Tag) { $rel = Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" }
  else {
    $rel = Invoke-RestMethod -Headers $ghHeaders -Uri "https://api.github.com/repos/$Repo/releases?per_page=50" |
      Where-Object { $_.tag_name -like 'os-v*' -and -not $_.draft } | Select-Object -First 1
  }
  if (-not $rel) { throw 'لا يوجد إصدار os-v* بعد. / no os-v* release yet' }
  Say "الإصدار: $($rel.tag_name)" $rel.html_url
  $whole = $rel.assets | Where-Object { $_.name -like '*-amd64.iso' } | Select-Object -First 1
  $parts = @($rel.assets | Where-Object { $_.name -like '*-amd64.iso.part*' } | Sort-Object name)
  $name = if ($whole) { $whole.name } elseif ($parts.Count) { $parts[0].name -replace '\.part\d+$', '' } else { throw 'ISO asset not found' }
  if ($whole) { Say "تحميل $name…" 'downloading ISO'; Save-Url $whole.browser_download_url $iso }
  else {
    $out = [IO.File]::Create($iso)
    try {
      foreach ($p in $parts) {
        $pd = Join-Path $dir $p.name
        Say "تحميل $($p.name)…" 'downloading part'
        Save-Url $p.browser_download_url $pd
        $in = [IO.File]::OpenRead($pd); try { $in.CopyTo($out, 8MB) } finally { $in.Dispose() }
        Remove-Item -Force $pd
      }
    } finally { $out.Dispose() }
  }
  $sums = $rel.assets | Where-Object { $_.name -eq 'SHA256SUMS' } | Select-Object -First 1
  if ($sums) {
    $sf = Join-Path $dir 'SHA256SUMS'; Save-Url $sums.browser_download_url $sf
    $line = Get-Content $sf | Where-Object { $_ -match ([regex]::Escape($name) + '$') } | Select-Object -First 1
    if ($line) {
      $exp = ($line -split '\s+')[0].ToLower()
      Say 'التحقق من SHA256…' 'verifying'
      if ((Get-FileHash -Algorithm SHA256 $iso).Hash.ToLower() -ne $exp) { throw 'SHA256 mismatch — delete the ISO and retry' }
    }
  }
}

# ---------------------------------------------------------------- GRUB entry
$entry = @'
# --- Alhajda live ISO from the Windows partition (Grub2Win custom entry) ---
menuentry "Alhajda Live (ISO on Windows disk)" {
    insmod part_gpt
    insmod ntfs
    insmod exfat
    insmod fat
    insmod iso9660
    insmod loopback
    set isofile="/alhajda/alhajda.iso"
    search --no-floppy --file --set=root $isofile
    loopback loop $isofile
    linux (loop)/casper/vmlinuz boot=casper iso-scan/filename=$isofile locale=ar_SA.UTF-8 quiet splash ---
    initrd (loop)/casper/initrd
}
'@
$entryFile = Join-Path $dir 'grub2win-alhajda-entry.cfg'
Set-Content -Path $entryFile -Value $entry -Encoding ASCII

Write-Host ''
Say "تم تجهيز: $iso" 'ISO ready'
Say "مدخل GRUB الجاهز: $entryFile" 'GRUB entry written'
Write-Host ''
Say 'الخطوات اليدوية التالية (على مسؤوليتك):' 'Next manual steps (at your own risk):'
Write-Host '  1) نزّل وثبّت Grub2Win:  https://sourceforge.net/projects/grub2win/'
Write-Host '  2) في Grub2Win: Manage Boot Menu → Add A New Entry → Type: Custom code → الصق محتوى الملف أعلاه.'
Write-Host '  3) أعد التشغيل واختر "Grub2Win" ثم "Alhajda Live".'
Write-Host '  4) (اختياري) للتثبيت الدائم بجانب ويندوز: أنشئ قسماً فارغاً من "إدارة الأقراص" ثم من داخل الجلسة الحية:'
Write-Host '       sudo alhajda-install-disk --target /dev/<القسم-الجديد>'
Write-Host '  لإزالة كل شيء: احذف المجلد ' -NoNewline; Write-Host $dir -NoNewline; Write-Host ' وألغِ تثبيت Grub2Win.'
