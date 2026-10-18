@echo off
rem Alhajda OS setup - double-click to install Alhajda as a virtual machine (no USB stick).
rem Same as running in PowerShell:  irm https://alhajda.com/os.ps1 ^| iex
rem Optional arguments are passed to the installer, e.g.:  AlhajdaSetup.cmd -MemoryGB 6 -DiskGB 80
title Alhajda OS Setup
setlocal
rem keep ALHAJDA_ARGS from the environment unless arguments were given
if not "%~1"=="" set "ALHAJDA_ARGS=%*"
echo.
echo   Alhajda OS setup - alhajda.com/os
echo   Windows will ask for Administrator approval. Choose "Yes".
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor 3072; try { $s = Invoke-RestMethod -UseBasicParsing -Uri 'https://alhajda.com/os.ps1' } catch { $s = Invoke-RestMethod -UseBasicParsing -Uri 'https://raw.githubusercontent.com/elyasalothman/kamputer-alhajda/main/os/windows/os.ps1' }; Invoke-Expression ([string]$s)"
set "RC=%ERRORLEVEL%"
echo.
if not "%ALHAJDA_NOPAUSE%"=="1" pause
exit /b %RC%
