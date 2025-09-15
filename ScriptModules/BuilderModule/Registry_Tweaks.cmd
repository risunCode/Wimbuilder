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

set "MOUNT_DIR=%~1"

echo [MODULE] Registry Tweaks
echo.

:: Validate parameter
if "%MOUNT_DIR%"=="" (
    echo [ERROR] Mount directory parameter is missing!
    echo Usage: %~nx0 "mount_directory_path"
    exit /b 1
)

if not exist "%MOUNT_DIR%" (
    echo [ERROR] Mount directory does not exist: %MOUNT_DIR%
    exit /b 1
)

echo   - Loading registry hives...
set "SOFTWARE_LOADED=0"
set "DEFAULT_LOADED=0"
set "SYSTEM_LOADED=0"

reg load HKLM\MOUNTED_SOFTWARE "%MOUNT_DIR%\Windows\System32\config\SOFTWARE" >nul 2>&1
if !errorlevel! equ 0 (
    set "SOFTWARE_LOADED=1"
    echo     ^> SOFTWARE hive loaded successfully
) else (
    echo [WARNING] Failed to load SOFTWARE hive
)

reg load HKLM\MOUNTED_DEFAULT "%MOUNT_DIR%\Users\Default\NTUSER.DAT" >nul 2>&1
if !errorlevel! equ 0 (
    set "DEFAULT_LOADED=1"
    echo     ^> DEFAULT hive loaded successfully
) else (
    echo [WARNING] Failed to load DEFAULT hive
)

reg load HKLM\MOUNTED_SYSTEM "%MOUNT_DIR%\Windows\System32\config\SYSTEM" >nul 2>&1
if !errorlevel! equ 0 (
    set "SYSTEM_LOADED=1"
    echo     ^> SYSTEM hive loaded successfully
) else (
    echo [WARNING] Failed to load SYSTEM hive
)

:: Check if any hive was loaded successfully
if !SOFTWARE_LOADED! equ 0 if !DEFAULT_LOADED! equ 0 if !SYSTEM_LOADED! equ 0 (
    echo [ERROR] Cannot load required registry hives
    echo [INFO] Registry tweaks will be skipped
    goto :skip_registry
)

echo.

:: ========================================
:: APPLY REGISTRY TWEAKS (OPTIMIZED)
:: ========================================
echo   - Applying registry tweaks...

if !SOFTWARE_LOADED! equ 1 (
    echo     - SOFTWARE hive tweaks...
    call :APPLY_SOFTWARE_TWEAKS
)

if !DEFAULT_LOADED! equ 1 (
    echo     - DEFAULT hive tweaks...
    call :APPLY_DEFAULT_TWEAKS
)

if !SYSTEM_LOADED! equ 1 (
    echo     - SYSTEM hive tweaks...
    call :APPLY_SYSTEM_TWEAKS
)

:skip_registry
echo   - Unloading registry hives...
if !SOFTWARE_LOADED! equ 1 reg unload HKLM\MOUNTED_SOFTWARE >nul 2>&1
if !DEFAULT_LOADED! equ 1 reg unload HKLM\MOUNTED_DEFAULT >nul 2>&1
if !SYSTEM_LOADED! equ 1 reg unload HKLM\MOUNTED_SYSTEM >nul 2>&1

echo   Registry tweaks completed.
echo.
exit /b 0

:: ========================================
:: SOFTWARE HIVE TWEAKS (OPTIMIZED)
:: ========================================
:APPLY_SOFTWARE_TWEAKS
:: Remove virtual folders and context menu items
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f >nul 2>&1
reg delete "HKLM\MOUNTED_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f >nul 2>&1
reg delete "HKLM\MOUNTED_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\ModernSharing" /f >nul 2>&1
reg delete "HKLM\MOUNTED_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\Sharing" /f >nul 2>&1
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" /f >nul 2>&1

:: Remove OOBE updates
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate" /f >nul 2>&1
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate" /f >nul 2>&1

:: OOBE and policies tweaks
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t REG_SZ /d "hide:home" /f >nul 2>&1
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNRO" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v "ShippedWithReserves" /t REG_DWORD /d 0 /f >nul 2>&1
::reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d 1 /f >nul 2>&1

:: Disable updates
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate" /v "workCompleted" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" /v "workCompleted" /t REG_DWORD /d 1 /f >nul 2>&1

:: Cloud content policies
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableCloudOptimizedContent" /t REG_DWORD /d 1 /f >nul 2>&1

:: Windows 11 specific tweaks
if "%TARGET_WINDOWS_VER%"=="11" (
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "AllowRecallEnablement" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\System" /v "PublishUserActivities" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableConsumerAccountStateContent" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t REG_DWORD /d 0 /f >nul 2>&1
)
exit /b 0

:: ========================================
:: DEFAULT HIVE TWEAKS (OPTIMIZED)
:: ========================================
:APPLY_DEFAULT_TWEAKS
:: Explorer tweaks
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f >nul 2>&1

:: Disable content delivery manager (batch approach)
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "OemPreInstalledAppsEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "ContentDeliveryAllowed" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "FeatureManagementEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEverEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContentEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-310093Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338393Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353694Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353696Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d 0 /f >nul 2>&1

:: Remove subscriptions
reg delete "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions" /f >nul 2>&1

:: Windows 11 specific tweaks
if "%TARGET_WINDOWS_VER%"=="11" (
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v "TaskbarEndTask" /t REG_DWORD /d 1 /f >nul 2>&1
    
    :: RunOnce tweaks
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "RestoreWin10ContextMenu" /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32 /f /ve" /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "HideGalleryExplorer" /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c} /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f" /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "HideHomeExplorer1" /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903} /d CLSID_MSGraphHomeFolder /f /ve" /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "HideHomeExplorer2" /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903} /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f" /f >nul 2>&1
    
    :: Teams tweaks
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Office\Teams" /v "HomeUserAutoStartAfterInstall" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Office\Teams" /v "PreventFirstLaunchAfterInstall" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Policies\Microsoft\Office\Teams" /v "PreventFirstLaunchAfterInstall" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_DEFAULT\Software\Policies\Microsoft\Office\Teams" /v "AutoStart" /t REG_DWORD /d 0 /f >nul 2>&1
)
exit /b 0

:: ========================================
:: SYSTEM HIVE TWEAKS (OPTIMIZED)
:: ========================================
:APPLY_SYSTEM_TWEAKS
:: BitLocker tweaks
reg add "HKLM\MOUNTED_SYSTEM\ControlSet001\Control\BitLocker" /v "PreventDeviceEncryption" /t REG_DWORD /d 1 /f >nul 2>&1

:: Windows 11 system requirements bypass (Standard/Consumer only)
if "%TARGET_WINDOWS_VER%"=="11" if not "%TARGET_WINDOWS_TYPE%"=="LTSC" (
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d 1 /f >nul 2>&1
)
exit /b 0 