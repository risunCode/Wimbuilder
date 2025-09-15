@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Launcher Detection - Ensure script is run from WimBuilder
:: ============================================================================
if not defined ROOT_DIR (
    echo ============================================================================
    echo [ERROR] Please launch script from WimBuilder launcher.
    echo ============================================================================
    echo.
    echo This script module requires variables and paths that are set by
    echo WimBuilder_Launcher.cmd. Please run the launcher first.
    echo.
    pause
    exit /b 1
)

:: WIM Boot Order Changer - Optimized Module
echo.
echo ===== WIM BOOT ORDER CHANGER =====
echo.

:: Quick checks
if not exist "%WIM_FOLDER%" (
    echo ERROR: WIM folder not found: %WIM_FOLDER%
    pause
    exit /b 1
)

if not exist "%WIMLIB%" (
    echo ERROR: WimLib not found at "%WIMLIB%"
    pause
    exit /b 1
)

:: Initialize
set "SELECTED_WIM="
set "TOTAL_INDEXES=0"
set "CURRENT_BOOT_INDEX=0"

:MAIN
cls
echo ===== WIM BOOT ORDER CHANGER =====
echo.

:: List WIM files
echo Available WIM files in: %WIM_FOLDER%
echo.
set "WIM_COUNT=0"
for %%W in ("%WIM_FOLDER%\*.wim") do (
    set /a "WIM_COUNT+=1"
    set "WIM[!WIM_COUNT!]=%%W"
    echo [!WIM_COUNT!] %%~nxW
)

if !WIM_COUNT! equ 0 (
    echo No WIM files found!
    echo Place your WIM files in: %WIM_FOLDER%
    pause
    exit /b 1
)

echo.
if defined SELECTED_WIM (
    for %%F in ("!SELECTED_WIM!") do set "WIM_NAME=%%~nxF"
    echo Current: !WIM_NAME! ^(!TOTAL_INDEXES! indexes, boot: !CURRENT_BOOT_INDEX!^)
    echo.
    echo [1] Select different WIM
    echo [2] Change boot index
    echo [3] Show WIM details
    echo [4] Exit
) else (
    echo [1] Select WIM file
    echo [2] Exit
)

echo.
set /p "CHOICE=Choice: "

if defined SELECTED_WIM (
    if "!CHOICE!"=="1" goto :SELECT
    if "!CHOICE!"=="2" goto :CHANGE
    if "!CHOICE!"=="3" goto :DETAILS
    if "!CHOICE!"=="4" exit /b 0
) else (
    if "!CHOICE!"=="1" goto :SELECT
    if "!CHOICE!"=="2" exit /b 0
)
goto :MAIN

:SELECT
echo.
set /p "SEL=Select WIM (1-!WIM_COUNT!): "

:: Simple validation
if "!SEL!"=="" goto :SELECT
echo !SEL!| findstr /r "^[0-9]*$" >nul || goto :SELECT
if !SEL! lss 1 goto :SELECT
if !SEL! gtr !WIM_COUNT! goto :SELECT

call set "SELECTED_WIM=%%WIM[!SEL!]%%"

echo.
echo Analyzing WIM...
call :ANALYZE "!SELECTED_WIM!"
if !errorlevel! neq 0 (
    set "SELECTED_WIM="
    pause
)
goto :MAIN

:CHANGE
if !TOTAL_INDEXES! leq 1 (
    echo [ERROR] WIM has only 1 index - boot index not needed.
    pause
    goto :MAIN
)

echo.
echo === Change Boot Index ===
echo Current: !CURRENT_BOOT_INDEX! ^| Available: 1-!TOTAL_INDEXES!
echo.

:: Show indexes
dism /get-wiminfo /wimfile:"!SELECTED_WIM!" | findstr /C:"Index :" /C:"Name :"

echo.
set /p "NEW_INDEX=New boot index (1-!TOTAL_INDEXES!, 0=cancel): "

if "!NEW_INDEX!"=="0" goto :MAIN
echo !NEW_INDEX!| findstr /r "^[0-9]*$" >nul || goto :CHANGE
if !NEW_INDEX! lss 1 goto :CHANGE
if !NEW_INDEX! gtr !TOTAL_INDEXES! goto :CHANGE

echo.
set /p "CONFIRM=Set boot index to !NEW_INDEX!? (Y/N): "
if /i not "!CONFIRM!"=="Y" goto :MAIN

echo.
echo Setting boot index...
"%WIMLIB%" info "!SELECTED_WIM!" --boot !NEW_INDEX!
if !errorlevel! neq 0 (
    echo [ERROR] Failed to set boot index! Error code: !errorlevel!
    pause
    goto :MAIN
)

echo.
echo Boot index operation completed.
pause
goto :MAIN

:DETAILS
echo.
echo === WIM Details ===
dism /get-wiminfo /wimfile:"!SELECTED_WIM!"
pause
goto :MAIN

:ANALYZE
set "WIM_FILE=%~1"
set "TOTAL_INDEXES=0"
set "CURRENT_BOOT_INDEX=0"

:: Validate file exists
if not exist "%WIM_FILE%" (
    echo [ERROR] WIM file not found: %WIM_FILE%
    exit /b 1
)

:: Count indexes using quoted path
for /f "tokens=2 delims=:" %%i in ('dism /get-wiminfo /wimfile:"%WIM_FILE%" 2^>nul ^| findstr /C:"Index :"') do (
    set "IDX=%%i"
    set "IDX=!IDX: =!"
    if !IDX! gtr !TOTAL_INDEXES! set "TOTAL_INDEXES=!IDX!"
)

if !TOTAL_INDEXES! equ 0 (
    echo [ERROR] Invalid WIM file or no indexes found!
    exit /b 1
)

:: Get boot index using wimlib
for /f "tokens=3" %%i in ('"%WIMLIB%" info "%WIM_FILE%" 2^>nul ^| findstr /C:"Boot Index:"') do (
    set "CURRENT_BOOT_INDEX=%%i"
)

:: Handle different possible outputs from wimlib
if "!CURRENT_BOOT_INDEX!"=="" set "CURRENT_BOOT_INDEX=0"
if "!CURRENT_BOOT_INDEX!"=="None" set "CURRENT_BOOT_INDEX=0"
if "!CURRENT_BOOT_INDEX!"=="none" set "CURRENT_BOOT_INDEX=0"

echo Found !TOTAL_INDEXES! indexes, boot: !CURRENT_BOOT_INDEX!
exit /b 0 