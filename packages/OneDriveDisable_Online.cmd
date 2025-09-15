@echo off
echo [DISABLE] Menonaktifkan OneDrive...

:: Tambahkan policy untuk blok sinkronisasi
reg add "HKLM\Software\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d 1 /f >nul 2>&1

:: Refresh policy
gpupdate /force

echo [DONE] OneDrive dinonaktifkan. Reboot untuk efek penuh.
pause
