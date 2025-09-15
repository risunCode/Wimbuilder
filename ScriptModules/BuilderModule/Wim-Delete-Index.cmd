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

:: WIM Index Deletion Tool using DISM Export-Remove approach
:: Uses export method to properly remove indexes from WIM

echo.
echo ===== WIM INDEX DELETION TOOL =====
echo.

:: Quick checks
if not exist "%WIM_FOLDER%" (
    echo ERROR: WIM folder not found: %WIM_FOLDER%
    pause
    exit /b 1
)

if not exist "%MOUNT_DIR%" (
    echo Creating mount directory: %MOUNT_DIR%
    mkdir "%MOUNT_DIR%" >nul 2>&1
)

:: Check if DISM is available
dism /? >nul 2>&1
if errorlevel 1 (
    echo ERROR: DISM not found or not working!
    echo Please ensure DISM is available in your system.
    pause
    exit /b 1
)

:: Initialize variables
set "SELECTED_WIM="
set "SELECTED_WIM_NAME="
set "SELECTED_INDEX="
set "IS_MOUNTED=0"

:MAIN_MENU
cls
echo ===== WIM INDEX DELETION TOOL =====
echo.
echo Mount Directory: %MOUNT_DIR%
echo.

:: List available WIM files
echo === AVAILABLE WIM FILES ===
echo WIM files in: %WIM_FOLDER%
echo.

set "WIM_COUNT=0"
for %%W in ("%WIM_FOLDER%\*.wim") do (
    set /a "WIM_COUNT+=1"
    set "WIM[!WIM_COUNT!]=%%W"
    set "WIM_NAME[!WIM_COUNT!]=%%~nxW"
    echo [!WIM_COUNT!] %%~nxW
)

if !WIM_COUNT! equ 0 (
    echo No WIM files found in: %WIM_FOLDER%
    echo Please place your WIM files in: %WIM_FOLDER%
    pause
    exit /b 1
)

echo.
echo === CURRENT STATUS ===
if defined SELECTED_WIM (
    echo Selected WIM: !SELECTED_WIM_NAME!
    if defined SELECTED_INDEX (
        echo Selected Index: !SELECTED_INDEX!
        if !IS_MOUNTED! equ 1 (
            echo Status: MOUNTED and ready for deletion
        ) else (
            echo Status: Selected but not mounted
        )
    ) else (
        echo Status: WIM selected, index not chosen
    )
) else (
    echo Status: No WIM file selected
)

echo.
echo === OPTIONS ===
echo [1] Select WIM file and show indexes
echo [2] Delete selected index (no mount required)
echo [3] Mount WIM for inspection (optional)
echo [4] Unmount WIM (discard changes)
echo [5] Force cleanup all mount points
echo [6] Exit
echo.

set /p "CHOICE=Select option (1-6): "

if "!CHOICE!"=="1" goto :SELECT_WIM
if "!CHOICE!"=="2" goto :DELETE_INDEX
if "!CHOICE!"=="3" goto :MOUNT_WIM
if "!CHOICE!"=="4" goto :UNMOUNT_WIM
if "!CHOICE!"=="5" goto :FORCE_CLEANUP
if "!CHOICE!"=="6" goto :EXIT_SCRIPT
goto :MAIN_MENU

:SELECT_WIM
echo.

:WIM_SELECT_LOOP
set /p "WIM_SEL=Select WIM file (1-!WIM_COUNT!): "

if "!WIM_SEL!"=="" (
    echo [ERROR] Input cannot be empty!
    goto :WIM_SELECT_LOOP
)

echo !WIM_SEL!| findstr /r "^[0-9][0-9]*$" >nul
if !errorlevel! neq 0 (
    echo [ERROR] Please enter a valid number!
    goto :WIM_SELECT_LOOP
)

if !WIM_SEL! lss 1 (
    echo [ERROR] Selection must be at least 1!
    goto :WIM_SELECT_LOOP
)

if !WIM_SEL! gtr !WIM_COUNT! (
    echo [ERROR] Selection must be at most !WIM_COUNT!
    goto :WIM_SELECT_LOOP
)

call set "SELECTED_WIM=%%WIM[!WIM_SEL!]%%"
call set "SELECTED_WIM_NAME=%%WIM_NAME[!WIM_SEL!]%%"

echo.
echo === SELECTED WIM FILE ===
echo File: !SELECTED_WIM_NAME!
echo Path: !SELECTED_WIM!
echo.

:: Check disk space for operations
echo Checking disk space...
for %%A in ("!SELECTED_WIM!") do set "WIM_SIZE=%%~zA"
set /a "REQUIRED_SPACE=!WIM_SIZE! * 2"
for /f "tokens=3" %%B in ('dir "!SELECTED_WIM!" /-c ^| findstr /i "bytes free"') do set "FREE_SPACE=%%B"
if !FREE_SPACE! lss !REQUIRED_SPACE! (
    echo [WARNING] Low disk space detected!
    echo WIM Size: !WIM_SIZE! bytes
    echo Free Space: !FREE_SPACE! bytes
    echo Recommended: At least double the WIM size for safe operations
    echo.
)

:: Show available indexes using DISM
echo === AVAILABLE INDEXES ===
echo Scanning WIM file...

dism /get-wiminfo /wimfile:"!SELECTED_WIM!"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to read WIM file information!
    echo This file may be corrupted or invalid.
    set "SELECTED_WIM="
    set "SELECTED_WIM_NAME="
    pause
    goto :MAIN_MENU
)

echo.

:: Count total indexes and warn if only 1
set "TOTAL_INDEXES=0"
for /f "tokens=2 delims=:" %%i in ('dism /get-wiminfo /wimfile:"!SELECTED_WIM!" 2^>nul ^| findstr /C:"Index :"') do (
    set "CURRENT_INDEX=%%i"
    set "CURRENT_INDEX=!CURRENT_INDEX: =!"
    if !CURRENT_INDEX! gtr !TOTAL_INDEXES! set "TOTAL_INDEXES=!CURRENT_INDEX!"
)

if !TOTAL_INDEXES! leq 1 (
    echo WARNING: This WIM file has only 1 index!
    echo Deleting the last index will make the WIM file unusable.
    echo.
)

:: Ask for index to select
:INDEX_SELECT_LOOP
set /p "INDEX_SEL=Enter index number to select (0 to cancel): "

if "!INDEX_SEL!"=="" (
    echo [ERROR] Index number cannot be empty!
    goto :INDEX_SELECT_LOOP
)

if "!INDEX_SEL!"=="0" (
    echo Selection cancelled.
    goto :MAIN_MENU
)

echo !INDEX_SEL!| findstr /r "^[0-9][0-9]*$" >nul
if !errorlevel! neq 0 (
    echo [ERROR] Please enter a valid number!
    goto :INDEX_SELECT_LOOP
)

if !INDEX_SEL! lss 1 (
    echo [ERROR] Index must be 1 or higher!
    goto :INDEX_SELECT_LOOP
)

if !INDEX_SEL! gtr !TOTAL_INDEXES! (
    echo [ERROR] Index !INDEX_SEL! not found! Maximum is !TOTAL_INDEXES!
    goto :INDEX_SELECT_LOOP
)

:: Validate index exists by getting specific index info
dism /get-wiminfo /wimfile:"!SELECTED_WIM!" /index:!INDEX_SEL! >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Index !INDEX_SEL! not found in WIM file!
    goto :INDEX_SELECT_LOOP
)

set "SELECTED_INDEX=!INDEX_SEL!"

echo.
echo SUCCESS: Selection complete!
echo File: !SELECTED_WIM_NAME!
echo Index: !SELECTED_INDEX!
echo.
echo Next: Use option [2] to delete this index.
pause
goto :MAIN_MENU

:DELETE_INDEX
if not defined SELECTED_WIM (
    echo [ERROR] Please select a WIM file first (option 1)
    pause
    goto :MAIN_MENU
)

if not defined SELECTED_INDEX (
    echo [ERROR] Please select an index first (option 1)
    pause
    goto :MAIN_MENU
)

echo.
echo === DELETE INDEX FROM WIM ===
echo.
echo WARNING: This will permanently delete the selected index!
echo.
echo WIM File: !SELECTED_WIM_NAME!
echo Index to Delete: !SELECTED_INDEX!
echo.
echo This operation will:
echo - Create a new WIM without the selected index
echo - Replace the original WIM file
echo - Renumber remaining indexes automatically
echo - Cannot be undone after completion
echo.

set /p "CONFIRM=Are you sure you want to proceed? (Y/N): "

if /i not "!CONFIRM!"=="Y" (
    echo Operation cancelled.
    pause
    goto :MAIN_MENU
)

echo.
echo === STARTING DELETE OPERATION ===
echo.

:: Force cleanup before operation
echo Preparing for operation...
call :FORCE_CLEANUP_SILENT

:: Create temporary file name with timestamp
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do if not "%%I"=="" set "DATETIME=%%I"
set "TIMESTAMP=!DATETIME:~0,8!_!DATETIME:~8,6!"
set "TEMP_WIM=!SELECTED_WIM!.temp_!TIMESTAMP!"

echo [1/3] Creating new WIM without selected index...
echo Temporary file: !TEMP_WIM!

:: Export all indexes except the one to delete
set "EXPORT_SUCCESS=0"
set "EXPORTED_COUNT=0"

for /f "tokens=2 delims=:" %%i in ('dism /get-wiminfo /wimfile:"!SELECTED_WIM!" 2^>nul ^| findstr /C:"Index :"') do (
    set "CURRENT_INDEX=%%i"
    set "CURRENT_INDEX=!CURRENT_INDEX: =!"
    
    if not "!CURRENT_INDEX!"=="!SELECTED_INDEX!" (
        set /a "EXPORTED_COUNT+=1"
        echo Exporting index !CURRENT_INDEX! ^(!EXPORTED_COUNT! of remaining indexes^)...
        
        if !EXPORTED_COUNT! equ 1 (
            :: First export creates new WIM
            dism /export-image /sourceimagefile:"!SELECTED_WIM!" /sourceindex:!CURRENT_INDEX! /destinationimagefile:"!TEMP_WIM!" /compress:max
        ) else (
            :: Subsequent exports append to existing WIM
            dism /export-image /sourceimagefile:"!SELECTED_WIM!" /sourceindex:!CURRENT_INDEX! /destinationimagefile:"!TEMP_WIM!"
        )
        
        if !errorlevel! neq 0 (
            echo [ERROR] Failed to export index !CURRENT_INDEX!!
            if exist "!TEMP_WIM!" del "!TEMP_WIM!" >nul 2>&1
            pause
            goto :MAIN_MENU
        )
    )
)

if !EXPORTED_COUNT! equ 0 (
    echo [ERROR] No indexes remaining after deletion!
    echo Cannot create empty WIM file.
    if exist "!TEMP_WIM!" del "!TEMP_WIM!" >nul 2>&1
    pause
    goto :MAIN_MENU
)

echo [2/3] Replacing original WIM file...

:: Replace original with new WIM
move "!SELECTED_WIM!" "!SELECTED_WIM!.old" >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Failed to backup original WIM!
    if exist "!TEMP_WIM!" del "!TEMP_WIM!" >nul 2>&1
    pause
    goto :MAIN_MENU
)

move "!TEMP_WIM!" "!SELECTED_WIM!" >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Failed to replace WIM file!
    echo Restoring original...
    move "!SELECTED_WIM!.old" "!SELECTED_WIM!" >nul 2>&1
    if exist "!TEMP_WIM!" del "!TEMP_WIM!" >nul 2>&1
    pause
    goto :MAIN_MENU
)

:: Clean up old file
del "!SELECTED_WIM!.old" >nul 2>&1

echo [3/3] Verifying new WIM file...
dism /get-wiminfo /wimfile:"!SELECTED_WIM!"
if !errorlevel! neq 0 (
    echo [WARNING] WIM file verification failed!
    echo File may be corrupted.
) else (
    echo SUCCESS: WIM file verified successfully!
)

echo.
echo ===== DELETE OPERATION COMPLETED =====
echo.
echo SUCCESS: Index !SELECTED_INDEX! has been deleted from !SELECTED_WIM_NAME!
echo Remaining indexes have been automatically renumbered.
echo.

:: Reset selection for safety
set "SELECTED_WIM="
set "SELECTED_WIM_NAME="
set "SELECTED_INDEX="

echo Index deletion process completed successfully!
echo.
pause
goto :MAIN_MENU

:MOUNT_WIM
if not defined SELECTED_WIM (
    echo [ERROR] Please select a WIM file first (option 1)
    pause
    goto :MAIN_MENU
)

if not defined SELECTED_INDEX (
    echo [ERROR] Please select an index first (option 1)
    pause
    goto :MAIN_MENU
)

if !IS_MOUNTED! equ 1 (
    echo [ERROR] A WIM is already mounted!
    echo Please unmount it first using option [4].
    pause
    goto :MAIN_MENU
)

echo.
echo === MOUNTING WIM FOR INSPECTION ===
echo.
echo File: !SELECTED_WIM_NAME!
echo Index: !SELECTED_INDEX!
echo Mount Directory: %MOUNT_DIR%
echo.

:: Force cleanup before mounting
echo Preparing for mount...
call :FORCE_CLEANUP_SILENT

:: Mount the WIM
echo Mounting WIM file...
dism /Mount-Image /ImageFile:"!SELECTED_WIM!" /Index:!SELECTED_INDEX! /MountDir:"%MOUNT_DIR%" /ReadOnly
if !errorlevel! neq 0 (
    echo [ERROR] Failed to mount WIM!
    echo.
    echo Possible causes:
    echo - WIM file is in use by another process
    echo - Insufficient permissions
    echo - Mount directory is not empty
    echo - Insufficient disk space
    pause
    goto :MAIN_MENU
)

set "IS_MOUNTED=1"

echo.
echo SUCCESS: WIM mounted successfully in READ-ONLY mode!
echo Mount point: %MOUNT_DIR%
echo.
echo You can now inspect the contents of this index.
echo Use option [4] to unmount when finished.
echo.
pause
goto :MAIN_MENU

:UNMOUNT_WIM
if !IS_MOUNTED! neq 1 (
    echo [INFO] No WIM is currently mounted.
    pause
    goto :MAIN_MENU
)

echo.
echo === UNMOUNT WIM ===
echo.
echo This will unmount the currently mounted WIM.
echo.
echo Mounted WIM: !SELECTED_WIM_NAME!
echo Mounted Index: !SELECTED_INDEX!
echo.

set /p "CONFIRM_UNMOUNT=Are you sure you want to unmount? (Y/N): "

if /i not "!CONFIRM_UNMOUNT!"=="Y" (
    echo Operation cancelled.
    pause
    goto :MAIN_MENU
)

echo.
echo Unmounting WIM...
dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /Discard >nul 2>&1
if !errorlevel! neq 0 (
    echo [WARNING] Unmount operation may have failed.
    echo Forcing cleanup...
    call :FORCE_CLEANUP_SILENT
) else (
    echo SUCCESS: WIM unmounted successfully.
)

set "IS_MOUNTED=0"
echo.
pause
goto :MAIN_MENU

:FORCE_CLEANUP
echo.
echo === FORCE CLEANUP ALL ===
echo.
echo WARNING: This will force cleanup ALL mount points and registry hives!
echo This is an emergency operation for when normal operations fail.
echo.
set /p "CONFIRM_FORCE=Are you sure you want to force cleanup? (Y/N): "
if /i not "!CONFIRM_FORCE!"=="Y" (
    echo Operation cancelled.
    pause
    goto :MAIN_MENU
)

call :FORCE_CLEANUP_SILENT

echo.
echo SUCCESS: Force cleanup completed successfully!
echo All mount points and registry hives have been cleaned up.

set "IS_MOUNTED=0"
echo.
pause
goto :MAIN_MENU

:FORCE_CLEANUP_SILENT
:: Force cleanup mount points
dism /Cleanup-Mountpoints >nul 2>&1

:: Force unload registry hives
reg unload HKLM\MOUNTED_SOFTWARE >nul 2>&1
reg unload HKLM\MOUNTED_DEFAULT >nul 2>&1
reg unload HKLM\MOUNTED_SYSTEM >nul 2>&1
reg unload HKLM\MOUNTED_SAM >nul 2>&1
reg unload HKLM\MOUNTED_SECURITY >nul 2>&1

:: Force unmount any mounted images
if exist "%MOUNT_DIR%" (
    dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /Discard >nul 2>&1
)
goto :eof

:EXIT_SCRIPT
if !IS_MOUNTED! equ 1 (
    echo.
    echo WARNING: A WIM is still mounted!
    echo.
    set /p "EXIT_CONFIRM=Do you want to unmount and exit? (Y/N): "
    if /i "!EXIT_CONFIRM!"=="Y" (
        echo Unmounting WIM...
        dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /Discard >nul 2>&1
    ) else (
        goto :MAIN_MENU
    )
)

echo.
echo Performing final cleanup...
call :FORCE_CLEANUP_SILENT
echo Goodbye!
exit /b 0 