@echo off
setlocal

where py >nul 2>nul
if errorlevel 1 (
  echo Python launcher ^(py^) not found. Install Python 3.11+ and try again.
  exit /b 1
)

py -3.11 -m nanobot %*
