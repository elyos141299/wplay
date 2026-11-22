// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay — AirPlay receiver mandiri untuk Windows.
// Titik masuk ini adalah versi sangat kecil dari src/main.rs
// iDescriptor v0.6.1: semua QObject iDevice (apps, backup, galeri,
// ifuse, updater, settings, ...) dibuang; yang dipertahankan hanya
// AirplayImp dan pemuatan QML (filesystem saat debug, qrc saat rilis,
// sama seperti pola upstream).

// DIAGNOSIS SEMENTARA (Phase 3): atribut windows_subsystem dimatikan
// supaya build rilis berjalan sebagai aplikasi konsol dan semua log
// (termasuk pesan fatal GLib/GStreamer sebelum crash 0x40000015 di
// libglib-2.0-0.dll) tercetak ke jendela cmd. KEMBALIKAN baris di
// bawah ini setelah penyebab crash ketemu:
// #![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use qmetaobject::prelude::*;
use tracing_subscriber::{EnvFilter, filter::LevelFilter, prelude::*};

pub mod airplay;
pub mod device_names;
pub mod gst_gl;
pub mod qt_threading;
pub mod settings;
#[cfg(not(debug_assertions))]
pub mod ui_qrc;

fn main() {
    let filter = EnvFilter::builder()
        .with_default_directive(LevelFilter::DEBUG.into())
        .from_env_lossy();
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer().compact())
        .with(filter)
        .init();

    qmetaobject::log::init_qt_to_rust();

    // FIXME: upstream memanggil native::configure_application() (nama
    // aplikasi/organisasi Qt, font bawaan Windows, dll). wPlay belum
    // punya lapisan native Rust; nama aplikasi mengikuti nama binary
    // ("wplay"). Tambahkan bila nanti perlu QSettings/branding penuh.
    // Bagian configure_application yang WAJIB sudah diporting:
    // QQuickWindow::setGraphicsApi(OpenGL) — lihat
    // gst_gl::force_opengl_graphics_api() di bawah.

    #[cfg(not(debug_assertions))]
    crate::ui_qrc::qml();

    // Sama seperti upstream: di build rilis Windows, plugin GStreamer
    // dibundel di folder gstreamer-1.0 di sebelah file .exe.
    #[cfg(all(target_os = "windows", not(debug_assertions)))]
    {
        unsafe {
            let exe_dir = std::env::current_exe()
                .unwrap()
                .parent()
                .unwrap()
                .to_path_buf();
            let gst_plugin_path = exe_dir.join("gstreamer-1.0");
            std::env::set_var(
                "GST_PLUGIN_PATH",
                gst_plugin_path.to_string_lossy().to_string(),
            );
        }
    }

    // wPlay (Phase 3): paksa OpenGL untuk Qt Quick sebelum jendela
    // dibuat — qml6glsink tidak bisa jalan di atas renderer
    // Direct3D bawaan Qt 6 Windows (lihat gst_gl.rs).
    #[cfg(not(target_os = "linux"))]
    crate::gst_gl::force_opengl_graphics_api();

    // wPlay (Phase 3, tes perangkat pertama): muat plugin qml6glsink
    // SEBELUM Main.qml dibaca engine. Tipe GstGLQt6VideoItem yang
    // di-import Main.qml baru terdaftar ke QML saat plugin GStreamer
    // itu dimuat (itu gunanya force_load_gst_gl di upstream, dan di
    // sana urutannya memang begitu: load_gst_gl dipanggil dari
    // Toolbox sebelum Airplay.qml dibuka). Versi pertama wPlay
    // memanggilnya DARI DALAM QML setelah dokumen dimuat — mustahil
    // berhasil: dokumennya gagal dimuat total, aplikasi jalan terus
    // di latar belakang tanpa jendela sama sekali.
    let _ = crate::gst_gl::force_load_gst_gl();

    let mut engine = QmlEngine::new();

    let airplay = QObjectBox::new(airplay::Airplay::default());
    engine.set_object_property("AirplayImp".into(), airplay.pinned());

    if cfg!(debug_assertions) {
        // Mode debug: muat QML langsung dari source supaya gampang diubah.
        let path = format!("{}/src/ui/Main.qml", env!("CARGO_MANIFEST_DIR"));
        engine.load_file(QString::from(path).into());
    } else {
        engine.load_url(QString::from("qrc:/src/ui/Main.qml").into());
    }

    engine.exec();
}
