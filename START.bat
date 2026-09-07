@echo off
chcp 65001 >nul
cd /d "%~dp0"

if exist "Kamputer-Alhajda.exe" (
  start "" "Kamputer-Alhajda.exe"
  exit /b 0
)

if exist "win-unpacked\Kamputer-Alhajda.exe" (
  start "" "win-unpacked\Kamputer-Alhajda.exe"
  exit /b 0
)

echo لم يُوجد Kamputer-Alhajda.exe — لا تشغّل electron.exe.
exit /b 1
