@echo off
echo [ENABLE] Mengaktifkan OneDrive...

:: Hapus policy yang memblokir sinkronisasi
reg delete "HKLM\Software\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /f

:: Optional: hapus key jika kosong
reg delete "HKLM\Software\Policies\Microsoft\Windows\OneDrive" /f 

:: Refresh policy
gpupdate /force

:: Restart Explorer
taskkill /f /im explorer.exe
start explorer.exe

echo [DONE] OneDrive seharusnya aktif setelah reboot.
pause
