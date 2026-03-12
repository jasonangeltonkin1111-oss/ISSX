@echo off
setlocal
set CHM_PATH=%~dp0..\knowledge\raw\mql5.chm
set OUT_DIR=%~dp0..\knowledge\extracted_mql5_docs
if not exist "%CHM_PATH%" (
  echo CHM not found: %CHM_PATH%
  exit /b 1
)
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
echo Extracting %CHM_PATH% to %OUT_DIR%
hh.exe -decompile "%OUT_DIR%" "%CHM_PATH%"
echo Done.
