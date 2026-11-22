// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: pengganti lokal untuk settings_manager::airplay_uxplay_args()
// dari iDescriptor v0.6.1. Upstream membaca 3 pengaturan dari QSettings
// (FPS, no-hold, legacy ports); wPlay belum punya layar pengaturan,
// jadi nilainya jadi konstanta di sini — sama dengan nilai bawaan
// upstream: FPS 60, -nohold aktif, legacy ports aktif (khusus Linux).
//
// Satu tambahan wPlay: argumen "-n wPlay -nh" supaya nama server
// AirPlay yang muncul di iPhone adalah "wPlay" persis. Tanpa ini,
// nama bawaannya adalah "iDescriptor@UxPlay" (DEFAULT_NAME di
// lib/uxplay/uxplay.cpp) dan UxPlay menempelkan "@<nama PC>" di
// belakang nama server; "-nh" mematikan tempelan itu.

/// Nama server AirPlay yang tampil di iPhone (Screen Mirroring).
pub const SERVER_NAME: &str = "wPlay";

/// Frame rate maksimum yang diiklankan ke iPhone (bawaan upstream: 60).
pub const AIRPLAY_FPS: u32 = 60;

/// Susun argumen baris perintah untuk UxPlay, meniru
/// settings_manager::airplay_uxplay_args() v0.6.1 dengan nilai bawaan.
pub fn airplay_uxplay_args() -> Vec<String> {
    let args = vec![
        "uxplay".to_string(),
        "-n".to_string(),
        SERVER_NAME.to_string(),
        "-nh".to_string(),
        "-fps".to_string(),
        AIRPLAY_FPS.to_string(),
        "-nohold".to_string(),
    ];

    // Sama seperti upstream: legacy ports hanya di Linux.
    #[cfg(target_os = "linux")]
    args.push("-p".to_string());

    args
}
