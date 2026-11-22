# BASELINE TERKUNCI — wPlay (23 Nov 2026)

Dokumen ini menandai keadaan wPlay yang **terbukti jalan normal di PC
user** (build final: GUI tanpa konsol + tampilan profesional + ikon,
dikonfirmasi user 23 Nov 2026 ~01:17 WIB "oke normal"). Atas perintah
user, sistem ini **disimpan dan tidak boleh diubah sembarangan**.

## Yang TERKUNCI (jangan diubah tanpa persetujuan eksplisit user)

1. **build.rs** — terutama:
   - `.define("NO_MARCH_NATIVE", "ON")` untuk CMake native. Ini fix
     crash 0xc000001d (AVX-512 dari `-march=native` bawaan UxPlay,
     `lib/uxplay/lib/CMakeLists.txt`). Menghapus/mengubah baris ini
     mengembalikan lotere crash di CPU tanpa AVX-512 (mis. i3-12100F).
   - Langkah tanam ikon (windres, best-effort) — terbukti bukan
     penyebab crash; biarkan apa adanya.
2. **.github/workflows/build-windows.yml** — versi yang menghasilkan
   build normal ini. Versi kunci: Qt 6.9.3, GStreamer good 1.26.2,
   gst-libav 1.28.9, gst-plugins-bad 1.28.9, libplist 2.7.0.
3. **src/native/** dan **lib/uxplay** (commit UxPlay eaca2458) —
   lapisan native/server AirPlay. Tidak disentuh untuk urusan
   tampilan.
4. **src/main.rs, src/gst_gl.rs, src/airplay.rs, src/settings.rs** —
   termasuk `windows_subsystem = "windows"` (mode GUI) dan
   `force_opengl_graphics_api()` (wajib untuk qml6glsink di Windows).

## Yang BOLEH diubah bebas (jalur tampilan)

- **src/ui/Main.qml** — seluruh tampilan (warna, logo, teks, tombol,
  slider, layout) hidup di file ini saja. QML bersifat interpreted:
  kesalahan di sini paling jauh membuat tampilan tidak muncul —
  **tidak bisa** mengembalikan crash instruksi CPU, karena crash itu
  berasal dari flag kompilasi kode native, bukan dari tampilan.
- File dokumentasi (docs/, README).

## Aturan main ke depan

- Pembaruan tampilan = ubah Main.qml saja, build ulang, selesai.
  Sistem inti tidak ikut tersentuh.
- Perubahan apa pun di luar Main.qml harus disebut alasannya dan
  menunggu persetujuan user.
- Folder hasil build yang sedang jalan normal di PC user adalah
  salinan emas — build percobaan berikutnya ekstrak ke folder lain,
  jangan menimpa folder ini.
