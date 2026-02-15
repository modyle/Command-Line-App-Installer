@echo off
title Command Line App Installer v1.0
setlocal DisableDelayedExpansion

if not exist "%LOCALAPPDATA%\WinRTInstaller" mkdir "%LOCALAPPDATA%\WinRTInstaller"
set "CONFIG_FILE=%LOCALAPPDATA%\WinRTInstaller\config.dat"

if exist "%CONFIG_FILE%" (
    set /p APP_ROOT=<"%CONFIG_FILE%"
) else (
    set "APP_ROOT=C:\apps"
)

:menu
cls
echo ===============================================
echo        Command Line App Installer v1.0
echo ===============================================
echo  Current Install Root: %APP_ROOT%
echo ===============================================
echo.
echo  1. Install without Certificate (Unpack + Register)
echo  2. Register via AppxManifest.xml (Already Unpacked)
echo  3. Standard Install (Add-AppxPackage)
echo  4. Change Install Root Directory
echo  5. Exit
echo.
set /p choice="Select option [1-5]: "

if "%choice%"=="1" goto sub_mode1
if "%choice%"=="2" goto sub_mode2
if "%choice%"=="3" goto sub_mode3
if "%choice%"=="4" goto set_path
if "%choice%"=="5" exit
goto menu

:sub_mode1
cls
echo [Mode 1: Install without Certificate]
echo.
echo  1. Single File (.appx / .appxbundle)
echo  2. Bulk Install (Folder)
echo  3. Back to Menu
echo.
set /p sub="Selection: "
if "%sub%"=="1" goto mode1_single
if "%sub%"=="2" goto mode1_bulk
goto menu

:sub_mode2
cls
echo [Mode 2: Register via AppxManifest.xml]
echo.
echo  1. Single Folder (one app)
echo  2. Bulk Scan (Find all manifests in a folder)
echo  3. Back to Menu
echo.
set /p sub="Selection: "
if "%sub%"=="1" goto mode2_single
if "%sub%"=="2" goto mode2_bulk
goto menu

:sub_mode3
cls
echo [Mode 3: Standard Install]
echo.
echo  1. Single File
echo  2. Bulk Install
echo  3. Back to Menu
echo.
set /p sub="Selection: "
if "%sub%"=="1" goto mode3_single
if "%sub%"=="2" goto mode3_bulk
goto menu

:mode1_bulk
cls
echo [Bulk Install without Certificate]
set "SRC="
set /p "SRC=Enter folder path with apps: "

if defined SRC set "SRC=%SRC:"=%"

echo.
echo Scanning: "%SRC%"
echo.

for /f "delims=" %%F in ('dir /b /s "%SRC%\*.appx" "%SRC%\*.appxbundle" 2^>nul') do (
    echo Found file: "%%~nxF"
    call :install_logic_mode1 "%%F"
)

if not exist "%SRC%" (
    echo [!] Error: Folder not found or inaccessible.
)

echo.
echo Bulk operation finished.
pause
goto menu

:mode1_single
cls
set /p "RAW_PATH=Paste FULL path to .appx/.appxbundle: "
set "RAW_PATH=%RAW_PATH:"=%"
call :install_logic_mode1 "%RAW_PATH%"
pause
goto menu

:install_logic_mode1
set "FULL_PATH=%~1"
if not exist "%FULL_PATH%" exit /b

echo.
echo --- Processing: "%~nx1" ---

echo [1/5] Staging and Extracting...
set "STAGING=%TEMP%\rt_stage_%RANDOM%"
mkdir "%STAGING%" 2>nul
copy /y "%FULL_PATH%" "%TEMP%\temp.zip" >nul
powershell -Command "Expand-Archive -Path '%TEMP%\temp.zip' -DestinationPath '%STAGING%' -Force"
del "%TEMP%\temp.zip"

echo [2/5] Identifying App Core...
powershell -Command "$inner = Get-ChildItem '%STAGING%\*.appx' | Sort-Object Length -Descending | Select-Object -First 1; if($inner) { mkdir '%STAGING%\app_core' -Force; Expand-Archive -Path $inner.FullName -DestinationPath '%STAGING%\app_core' -Force }"
set "FINAL_SRC=%STAGING%"
if exist "%STAGING%\app_core\AppxManifest.xml" set "FINAL_SRC=%STAGING%\app_core"

echo [3/5] Extracting Identity Name...
set "A_NAME="
for /f "tokens=2 delims==" %%a in ('findstr /i "Identity" "%FINAL_SRC%\AppxManifest.xml" ^| findstr /i "Name="') do (
    for /f "tokens=1 delims= " %%b in ("%%~a") do set "A_NAME=%%~b"
)
set "A_NAME=%A_NAME:"=%"

if "%A_NAME%"=="" set "A_NAME=%~n1"
set "A_NAME=%A_NAME: =%"
set "T_DIR=%APP_ROOT%\%A_NAME%"

echo [4/5] Building Clean Root at: "%T_DIR%"
if exist "%T_DIR%" rd /s /q "%T_DIR%"
mkdir "%T_DIR%" 2>nul
xcopy "%FINAL_SRC%\*" "%T_DIR%\" /s /e /y /q >nul

del /f /q "%T_DIR%\AppxSignature.p7x" "%T_DIR%\AppxBlockMap.xml" 2>nul
rd /s /q "%T_DIR%\AppxMetadata" 2>nul
icacls "%T_DIR%" /grant *S-1-15-2-1:(OI)(CI)(RX) /T >nul

echo [5/5] Registering...
powershell Add-AppxPackage -Register %T_DIR%\AppxManifest.xml

if %errorlevel% neq 0 (echo [!] Failed.) else (echo [OK] Installed.)
rd /s /q "%STAGING%" 2>nul
exit /b

:mode2_single
set /p "M_DIR=Enter folder path: "
set "M_DIR=%M_DIR:"=%"
call :register_logic_mode2 "%M_DIR%"
pause
goto menu

:mode2_bulk
set /p "S_DIR=Enter root folder to scan: "
set "S_DIR=%S_DIR:"=%"
for /f "delims=" %%M in ('dir /s /b "%S_DIR%\AppxManifest.xml"') do (
    call :register_logic_mode2 "%%~dpM"
)
pause
goto menu

:register_logic_mode2
set "R_DIR=%~1"
echo.
echo >>> Registering at: %R_DIR%
icacls "%R_DIR%." /grant *S-1-15-2-1:(OI)(CI)(RX) /T >nul
powershell -Command "cd '%R_DIR%'; Add-AppxPackage -Register 'AppxManifest.xml' -DisableDevelopmentMode"
exit /b

:mode3_single
set /p "F_P=Enter file path: "
powershell -Command "Add-AppxPackage -Path '%F_P:"=%'"
pause
goto menu

:mode3_bulk
set /p "S_D=Enter folder: "
set "S_D=%S_D:"=%"
for %%F in ("%S_D%\*.appx" "%S_D%\*.appxbundle") do (
    echo Installing %%~nxF
    powershell -Command "Add-AppxPackage -Path '%%F'"
)
pause
goto menu

:set_path
cls
set /p "APP_ROOT=Enter new install root (e.g. C:\apps): "
echo %APP_ROOT%>"%CONFIG_FILE%"
goto menu