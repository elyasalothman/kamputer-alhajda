# Desktop + Start Menu shortcuts named «كمبيوتر الهجدة».
# Target is always Kamputer-Alhajda.exe — never electron.exe.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $here "Kamputer-Alhajda.exe"
if (-not (Test-Path $exe)) {
    $nested = Join-Path $here "win-unpacked\Kamputer-Alhajda.exe"
    if (Test-Path $nested) { $exe = $nested }
}
if (-not (Test-Path $exe)) {
    throw "Kamputer-Alhajda.exe not found next to this script."
}

$displayName = "كمبيوتر الهجدة"
$shell = New-Object -ComObject WScript.Shell
$targets = @(
    [Environment]::GetFolderPath("Desktop"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs")
)

foreach ($dir in $targets) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $lnk = $shell.CreateShortcut((Join-Path $dir "$displayName.lnk"))
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = Split-Path -Parent $exe
    $lnk.Description = $displayName
    $lnk.Save()
}

Write-Host "Shortcuts point to $exe ($displayName)"
