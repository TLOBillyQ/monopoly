@echo off
setlocal

set "ROOT=%~dp0"
set "PY_CMD="

for %%P in (py python python3) do (
  where %%P >nul 2>nul
  if not errorlevel 1 (
    if "%%P"=="py" (
      set "PY_CMD=py -3"
    ) else (
      set "PY_CMD=%%P"
    )
    goto :found
  )
)

:found
if "%PY_CMD%"=="" (
  echo Python not found. Install Python 3 and retry.
  exit /b 1
)

echo Exporting xlsx configs...
%PY_CMD% "%ROOT%scripts\export_xlsx.py"
if errorlevel 1 exit /b 1

echo Packaging Game.exe...
powershell -ExecutionPolicy Bypass -File "%ROOT%scripts\package_windows.ps1" -KeepGameExe
if errorlevel 1 exit /b 1

echo Done.
exit /b 0
