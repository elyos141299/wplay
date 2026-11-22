# wPlay

Aplikasi **AirPlay receiver mandiri** untuk Windows — cuma buat menerima
mirror layar iPhone ke PC (untuk ditangkap OBS saat streaming). Ringan,
tanpa fitur manajemen iPhone.

Nama server AirPlay yang muncul di iPhone: **wPlay**.

## Asal-usul

wPlay dibuat dari bagian AirPlay milik **iDescriptor v0.6.1**
(https://github.com/iDescriptor/iDescriptor, tag `v0.6.1`,
commit `f4d1c1bccf7c4b45244023a4d293018b19dd768c`), **Jalur A — UxPlay**:

- Di v0.6.1, receiver AirPlay yang sebenarnya adalah **UxPlay** (C/C++,
  submodule `lib/uxplay` di iDescriptor, commit terkunci
  `eaca2458946d8a283df3b872f25c6b7cc98be411`) yang ditempel ke aplikasi
  Rust + Qt lewat jembatan tipis `src/airplay.rs`.
- Library `rsplay` (Jalur B) **tidak dipakai** — keputusan user
  22 Nov 2026: Jalur A, karena v0.6.1/UxPlay sudah terbukti jalan
  di PC + iPhone user.
- Analisis lengkap: `../docs/EXTRACTION-ANALYSIS.md`.
- Laporan Phase 2: `../docs/PHASE2-REPORT.md`.

## Lisensi

- iDescriptor: **AGPL-3.0-or-later**
- UxPlay: **GPL-3.0**
- wPlay: **AGPL-3.0-or-later**

Karena memakai kode-kode di atas, **wPlay wajib open-source** dengan
lisensi yang kompatibel bila dibagikan ke orang lain, lengkap dengan
kredit ke penulis asli. Teks lisensi ada di `licenses/`
(`AGPL-3.0.txt`, `GPL-3.0.txt`) dan atribusi lengkap di
`licenses/NOTICE.md`.

## Status

**Phase 2 selesai (22 Nov 2026): kerangka kode terakit. Belum ada
build Windows yang berhasil dibuktikan.**

- [x] Clone iDescriptor v0.6.1 + bedah modul AirPlay (Phase 1)
- [x] Keputusan jalur: **A (UxPlay, dari v0.6.1)**
- [x] Submodule `lib/uxplay` terunduh di clone v0.6.1 & terverifikasi
      (commit `eaca245…`, lisensi GPL-3.0 dari source-nya sendiri)
- [x] Kerangka aplikasi Qt + Rust terkecil (lihat Struktur)
- [x] Dependensi `airplay.rs` ke iDescriptor diputus
      (settings / device_db / utils → modul lokal wPlay)
- [x] Lisensi AGPL-3.0 + GPL-3.0 + atribusi disertakan
- [x] Cek sebagian di sandbox Linux: modul murni Rust lolos
      compile + uji fungsi; crate `macros` lolos `cargo check`;
      `cargo check` penuh berhenti di "qmake not found" (sandbox
      tidak punya Qt — wajar, bukan error kode)
- [ ] Build Windows (hanya bisa di PC Windows / CI Windows)
- [ ] Tes di iPhone + PC user

## Struktur

```
app/
  Cargo.toml / build.rs   paket Rust wPlay (target windows-gnu, bukan MSVC)
  src/
    main.rs               titik masuk kecil: QmlEngine + AirplayImp
    airplay.rs            jembatan Rust <-> UxPlay (dari v0.6.1, diadaptasi)
    settings.rs           pengganti lokal settings_manager (FPS 60, -nohold, nama "wPlay")
    device_names.rs       tabel kecil kode model iPhone -> nama jualan
    gst_gl.rs             2 fungsi GStreamer dari utils.rs upstream
    qt_threading.rs       penolong thread Qt (disalin dari v0.6.1)
    ui_qrc.rs             pendaftaran Main.qml ke qrc (build rilis)
    ui/Main.qml           jendela polos wPlay
    native/               CMake: rakit UxPlay jadi library statis
  lib/
    macros/               crate macro QtThreading (disalin dari v0.6.1)
    uxplay/               submodule UxPlay — ambil dengan scripts/fetch-uxplay.sh
  licenses/               AGPL-3.0.txt, GPL-3.0.txt, NOTICE.md
  scripts/fetch-uxplay.sh ambil UxPlay di commit terkunci v0.6.1
  .github/workflows/      draf build Windows di GitHub Actions (belum dijalankan)
```

## Cara build

Di PC Windows, ikuti panduan langkah-demi-langkah:
`../docs/BUILD-WINDOWS.md` (MSYS2/MinGW64, Rust target
`x86_64-pc-windows-gnu`, Qt 6.9.3 MinGW, Bonjour SDK, GStreamer/
FFmpeg/OpenSSL/libplist dari MSYS2).

Ringkasnya, di MSYS2 MINGW64 dari folder ini:

```bash
bash scripts/fetch-uxplay.sh
cargo build --release
# hasil: target/release/wplay.exe
```
