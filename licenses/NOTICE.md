# Atribusi & Lisensi wPlay

wPlay dibuat dari kode open-source berikut. Semua kredit milik
penulis aslinya.

## iDescriptor — AGPL-3.0-or-later

- Repo: https://github.com/iDescriptor/iDescriptor
- Versi yang dipakai: tag `v0.6.1`, commit
  `f4d1c1bccf7c4b45244023a4d293018b19dd768c`
- Penulis: Uncore (https://github.com/uncor3) dan kontributor iDescriptor
- Teks lisensi: `AGPL-3.0.txt` di folder ini (disalin dari file
  `LICENSE` iDescriptor v0.6.1)
- File wPlay yang berasal dari sini: `src/airplay.rs` (diadaptasi),
  `src/qt_threading.rs`, `src/gst_gl.rs` (dari `src/utils.rs`),
  `src/device_names.rs` (dari `src/device_db.rs`), `src/settings.rs`
  (dari `src/settings_manager.rs`), `src/ui/Main.qml` (penyederhanaan
  `src/ui/tools/Airplay.qml`), `build.rs`, `src/native/CMakeLists.txt`,
  dan crate `lib/macros`.

## UxPlay — GPL-3.0

- Repo: https://github.com/iDescriptor/uxplay (fork iDescriptor dari
  UxPlay upstream, https://github.com/FDH2/UxPlay)
- Commit yang dipakai: `eaca2458946d8a283df3b872f25c6b7cc98be411`
  (submodule `lib/uxplay` di iDescriptor v0.6.1)
- Teks lisensi: `GPL-3.0.txt` di folder ini (disalin dari file
  `LICENSE` di repo UxPlay pada commit di atas)
- UxPlay sendiri adalah turunan dari RPiPlay dan memakai library
  llhttp dan PlayFair di dalamnya; kredit lengkapnya ada di
  README dan file lisensi di dalam repo UxPlay.

## Konsekuensi untuk wPlay

Karena kode di atas berlisensi AGPL-3.0 dan GPL-3.0, **wPlay adalah
open-source**: bila wPlay dibagikan ke orang lain, kode sumbernya
wajib ikut dibuka dengan lisensi yang kompatibel (wPlay memakai
AGPL-3.0-or-later), dan atribusi ini harus dipertahankan.
