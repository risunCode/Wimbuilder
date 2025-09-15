# WimBuilder Release — Panduan Penggunaan (Bahasa Indonesia)

Dokumen ini menjelaskan cara memakai tool WimBuilder yang disediakan dalam repository ini. Tool ini membantu Anda memodifikasi image Windows (WIM) dengan aman: debloat fitur, terapkan registry tweaks, injeksi AppX (opsional), serta utilitas lain seperti merge WIM, edit info WIM, ubah boot index, dan hapus index.

## Ringkasan Fitur
- WIM Builder terpadu untuk Windows 10/11 (Standard/Consumer) dan 10/11 LTSC
- Debloater fitur, penghapusan AppX provisioning, dan tweak registry otomatis
- Opsional injeksi paket AppX (Consumer/LTSC)
- Utilitas:
  - Merge beberapa WIM menjadi satu
  - Hapus index tertentu dari WIM (dengan metode ekspor aman)
  - Ubah boot index WIM
  - Edit nama/description image pada WIM
  - Manajer mount (commit/discard/force cleanup)

## Prasyarat
- Windows 10/11, disarankan edisi dengan DISM lengkap
- Jalankan sebagai Administrator (launcher akan otomatis meminta elevation)
- Ruang kosong disk yang memadai (saran: >= 10GB atau 2x ukuran WIM yang diproses)
- DISM tersedia di sistem (built-in Windows)
- wimlib sudah disertakan: `packages/WimLib/wimlib-imagex.exe`

## Struktur Folder Penting
- `WimBuilder_Launcher.cmd` — titik masuk utama (menu)
- `Image_Kitchen/TargetWIM/` — tempat Anda meletakkan file `*.wim` sumber
- `Image_Kitchen/TempMount/` — mount point sementara (dibuat otomatis)
- `AppxPackage/` — paket AppX untuk injeksi (opsional)
  - `Consumer/` — paket tambahan untuk Windows 10/11 Standard/Consumer
  - `LTSC_W10/` dan `LTSC_W11/` — paket untuk Windows 10/11 LTSC
  - Catatan nama folder dependency (lihat bagian Catatan AppX Dependency)
- `ScriptModules/BuilderModule/` — modul-modul builder (debloat, tweaks, merge, dll.)
- `packages/WimLib/` — biner wimlib

## Persiapan Awal
1. Letakkan file `*.wim` yang ingin diproses ke dalam `Image_Kitchen/TargetWIM/`.
2. (Opsional) Siapkan paket AppX:
   - Consumer: taruh `*.Msixbundle`, `*.AppxBundle`, atau `*.Msix` di `AppxPackage/Consumer/`
   - LTSC:
     - Paket aplikasi di `AppxPackage/LTSC_W10/` atau `AppxPackage/LTSC_W11/`
     - Dependency bersama di folder dependency (lihat Catatan AppX Dependency)

## Menjalankan Aplikasi (Launcher)
1. Klik kanan `WimBuilder_Launcher.cmd` lalu pilih “Run as administrator”.
2. Pilih menu utama:
   - [1] WIM Builder (Windows 10/11/LTSC)
   - [2] WIM Merge Tool
   - [3] WIM Index Deletion Tool
   - [4] WIM Boot Order Changer
   - [5] WIM Info Editor
   - [6] Check Mounted Directories

### 1) WIM Builder
Alur kerja builder terpadu (`WimBuilder_Launcher.cmd`):
- Pilih target: Windows 10, Windows 11, Windows 10 LTSC, Windows 11 LTSC
- Step 1: Pilih file WIM sumber dan index-nya
  - Script menampilkan index/edisi via `dism /Get-WimInfo`
- Step 2: Scan paket AppX
  - Untuk Standard/Consumer: injeksi AppX tambahan opsional (default N)
  - Untuk LTSC: injeksi AppX (default Y jika paket tersedia)
- Step 3: Tentukan nama output (default: `install_tiny_w{ver}[_ltsc]`)
  - Output disimpan sebagai: `Image_Kitchen/out_<nama>.wim`
- Step 4: Pre-mount cleanup (otomatis membersihkan mount points & hive registry sementara)
- Step 5: Mount image (DISM)
- Step 6: Processing image
  - Menjalankan `ScriptModules/BuilderModule/Features_Debloater.cmd <MountDir>`
  - Menjalankan `ScriptModules/BuilderModule/Registry_Tweaks.cmd <MountDir>`
  - Injeksi AppX sesuai pilihan
- Unmount (commit) dan ekspor final WIM via `wimlib-imagex.exe export`

Hasil akhir ditampilkan dengan path lengkap ke file output.

### 2) WIM Merge Tool
- Menggabungkan beberapa WIM menjadi satu file WIM baru.
- Menu ada di `ScriptModules/BuilderModule/Wim-Merge-Simple.cmd`.
- Fitur:
  - Pilih banyak WIM, beri Name/Description per image
  - Pilih metode kompresi: LZX (universal) atau XPRESS + WIMBoot (modern)
  - Set boot index pada WIM hasil merge
  - Output: `Image_Kitchen/TargetWIM/<output>.wim`

### 3) WIM Index Deletion Tool
- Menghapus index tertentu dari sebuah WIM menggunakan metode ekspor (aman).
- Menu ada di `ScriptModules/BuilderModule/Wim-Delete-Index.cmd`.
- Alur:
  - Pilih WIM, pilih index yang ingin dihapus
  - Script mengekspor index lain ke WIM baru, mengganti file awal secara aman
  - Verifikasi hasil dengan DISM

### 4) WIM Boot Order Changer
- Mengubah boot index default pada WIM.
- Menu ada di `ScriptModules/BuilderModule/Wim-Boot-Order-Changer.cmd`.
- Menampilkan WIM, index total, lalu mengatur boot index via wimlib.

### 5) WIM Info Editor
- Mengubah Name/Description per index pada WIM.
- Menu ada di `ScriptModules/BuilderModule/WimInfo_Editor.cmd`.
- Menampilkan informasi lengkap WIM dan index, lalu memungkinkan rename/ubah deskripsi.

### 6) Check Mounted Directories
- Memeriksa mount-mount aktif, menampilkan daftar, lalu memberi aksi:
  - Commit perubahan
  - Discard (buang perubahan)
  - Show info mount
  - Force cleanup (darurat)
- Menu ada di `ScriptModules/BuilderModule/CheckMounted.cmd`.

## Catatan AppX Dependency (Penting)
Launcher mengharapkan variabel berikut:
- `APPX_DEPENDENCIES_LTSC = AppxPackage/SharedDependencies_LTSC`
- `APPX_DEPENDENCIES_CONSUMER = AppxPackage/SharedDependencies`

Di workspace saat ini, folder yang ada adalah:
- `AppxPackage/Consumer/`
- `AppxPackage/LTSC_W10/`
- `AppxPackage/LTSC_W11/`
- `AppxPackage/SharedDepedencies_Consumer/` (perhatikan ejaan “Depedencies” dan sufiks “_Consumer”)

Agar injeksi dependency berjalan, Anda bisa:
- Membuat folder sesuai yang diharapkan launcher, lalu menempatkan file `*.Appx` atau `*.Msix` di sana:
  - `AppxPackage/SharedDependencies_LTSC/`
  - `AppxPackage/SharedDependencies/`
- ATAU, menyesuaikan variabel path di `WimBuilder_Launcher.cmd` pada bagian:
  - `set "APPX_DEPENDENCIES_LTSC=%ROOT_DIR%AppxPackage\SharedDependencies_LTSC"`
  - `set "APPX_DEPENDENCIES_CONSUMER=%ROOT_DIR%AppxPackage\SharedDependencies"`

Pastikan penamaan folder dan lokasi file AppX/Dependency sesuai agar proses injeksi tidak terlewati.

## Tips dan Praktik Terbaik
- Selalu jalankan sebagai Administrator.
- Pastikan WIM tidak sedang digunakan aplikasi lain (antivirus, indexing, dll.).
- Sisakan ruang disk yang cukup (idealnya > dua kali ukuran WIM sumber).
- Jika terjadi kegagalan mount/unmount, gunakan menu `Check Mounted` → `Force Cleanup`.
- Untuk build Windows 11 Standard/Consumer, script sudah menambahkan tweak bypass requirement di `Registry_Tweaks.cmd`.

## Troubleshooting Umum
- Gagal Mount (Step 5):
  - Pastikan admin, cek ruang disk, cek WIM valid, jalankan `dism /Cleanup-Mountpoints`.
- Gagal Unmount (Commit):
  - Script akan fallback ke `Discard`. Jika tetap gagal, lakukan `Force Cleanup` dari modul atau restart.
- AppX tidak terinjeksi:
  - Periksa struktur folder dependency/paket (lihat Catatan AppX Dependency).
  - Pastikan ekstensi file sesuai: `.Appx`, `.Msix`, `.Msixbundle`, `.AppxBundle`.
- Export WIM gagal (wimlib):
  - Cek path `packages/WimLib/wimlib-imagex.exe` ada dan dapat dieksekusi.

## Keamanan dan Reversibilitas
- Builder melakukan perubahan pada image ter-mount lalu commit ke WIM sumber dan mengekspor hasil akhir ke `Image_Kitchen/out_*.wim`.
- Simpan cadangan WIM sumber Anda sebelum melakukan operasi besar.

## Referensi Skrip Utama
- `WimBuilder_Launcher.cmd`
  - Menu utama dan orkestrasi proses builder
- `ScriptModules/BuilderModule/Features_Debloater.cmd`
  - Menghapus AppX provisioning, disable/remove fitur/capabilities tertentu (kondisional Win10/11)
- `ScriptModules/BuilderModule/Registry_Tweaks.cmd`
  - Memuat hive registry mounted image, menerapkan tweak, lalu unload aman
- `ScriptModules/BuilderModule/Mount_Helper.cmd`
  - Fungsi bantu mount/unmount aman dengan cleanup registry
- `ScriptModules/BuilderModule/Wim-Merge-Simple.cmd`
- `ScriptModules/BuilderModule/Wim-Delete-Index.cmd`
- `ScriptModules/BuilderModule/Wim-Boot-Order-Changer.cmd`
- `ScriptModules/BuilderModule/WimInfo_Editor.cmd`
- `ScriptModules/BuilderModule/CheckMounted.cmd`

---
Jika Anda membutuhkan penyesuaian tambahan (misalnya daftar paket/fitur yang dihapus, tweak registry spesifik, atau otomatisasi AppX tertentu), silakan beri tahu apa yang ingin diubah. Saya dapat membantu menyesuaikan skrip agar sesuai kebutuhan Anda.
