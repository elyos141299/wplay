// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay — AirPlay receiver mandiri untuk Windows.
// Titik masuk ini adalah versi sangat kecil dari src/main.rs
// iDescriptor v0.6.1: semua QObject iDevice (apps, backup, galeri,
// ifuse, updater, settings, ...) dibuang; yang dipertahankan hanya
// AirplayImp dan pemuatan QML (filesystem saat debug, qrc saat rilis,
// sama seperti pola upstream).

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

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
