// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: tabel nama perangkat kecil, pengganti lokal untuk
// `device_db::find_by_identifier()` dari iDescriptor v0.6.1.
// Tabel upstream lengkapnya (2.500+ baris, semua perangkat Apple)
// tidak ikut disalin; di sini hanya kode model iPhone -> nama jualan,
// yang memang cuma dipakai untuk tulisan info koneksi AirPlay.
// Datanya berasal dari src/device_db.rs iDescriptor v0.6.1
// (yang sendiri merujuk libirecovery dari libimobiledevice).

/// Cari nama jualan dari kode model (mis. "iPhone18,3" -> "iPhone 17").
/// Mengembalikan None bila kode tidak dikenal; penelepon menampilkan
/// "Unknown" — sama seperti perilaku upstream (UNKNOWN_DEVICE).
pub fn find_display_name(identifier: &str) -> Option<&'static str> {
    IPHONE_DISPLAY_NAMES
        .iter()
        .find(|(model, _)| *model == identifier)
        .map(|(_, name)| *name)
}

static IPHONE_DISPLAY_NAMES: &[(&str, &str)] = &[
    ("iPhone1,1", "iPhone 2G"),
    ("iPhone1,2", "iPhone 3G"),
    ("iPhone2,1", "iPhone 3Gs"),
    ("iPhone3,1", "iPhone 4"),
    ("iPhone3,2", "iPhone 4"),
    ("iPhone3,3", "iPhone 4"),
    ("iPhone4,1", "iPhone 4s"),
    ("iPhone5,1", "iPhone 5"),
    ("iPhone5,2", "iPhone 5"),
    ("iPhone5,3", "iPhone 5c"),
    ("iPhone5,4", "iPhone 5c"),
    ("iPhone6,1", "iPhone 5s"),
    ("iPhone6,2", "iPhone 5s"),
    ("iPhone7,1", "iPhone 6 Plus"),
    ("iPhone7,2", "iPhone 6"),
    ("iPhone8,1", "iPhone 6s"),
    ("iPhone8,1", "iPhone 6s"),
    ("iPhone8,2", "iPhone 6s Plus"),
    ("iPhone8,2", "iPhone 6s Plus"),
    ("iPhone8,4", "iPhone SE"),
    ("iPhone8,4", "iPhone SE"),
    ("iPhone9,1", "iPhone 7"),
    ("iPhone9,2", "iPhone 7 Plus"),
    ("iPhone9,3", "iPhone 7"),
    ("iPhone9,4", "iPhone 7 Plus"),
    ("iPhone10,1", "iPhone 8"),
    ("iPhone10,2", "iPhone 8 Plus"),
    ("iPhone10,3", "iPhone X"),
    ("iPhone10,4", "iPhone 8"),
    ("iPhone10,5", "iPhone 8 Plus"),
    ("iPhone10,6", "iPhone X"),
    ("iPhone11,2", "iPhone XS"),
    ("iPhone11,4", "iPhone XS Max"),
    ("iPhone11,6", "iPhone XS Max"),
    ("iPhone11,8", "iPhone XR"),
    ("iPhone12,1", "iPhone 11"),
    ("iPhone12,3", "iPhone 11 Pro"),
    ("iPhone12,5", "iPhone 11 Pro Max"),
    ("iPhone12,8", "iPhone SE 2nd gen"),
    ("iPhone13,1", "iPhone 12 mini"),
    ("iPhone13,2", "iPhone 12"),
    ("iPhone13,3", "iPhone 12 Pro"),
    ("iPhone13,4", "iPhone 12 Pro Max"),
    ("iPhone14,2", "iPhone 13 Pro"),
    ("iPhone14,3", "iPhone 13 Pro Max"),
    ("iPhone14,4", "iPhone 13 mini"),
    ("iPhone14,5", "iPhone 13"),
    ("iPhone14,6", "iPhone SE 3rd gen"),
    ("iPhone14,7", "iPhone 14"),
    ("iPhone14,8", "iPhone 14 Plus"),
    ("iPhone15,2", "iPhone 14 Pro"),
    ("iPhone15,3", "iPhone 14 Pro Max"),
    ("iPhone15,4", "iPhone 15"),
    ("iPhone15,5", "iPhone 15 Plus"),
    ("iPhone16,1", "iPhone 15 Pro"),
    ("iPhone16,2", "iPhone 15 Pro Max"),
    ("iPhone17,1", "iPhone 16 Pro"),
    ("iPhone17,2", "iPhone 16 Pro Max"),
    ("iPhone17,3", "iPhone 16"),
    ("iPhone17,4", "iPhone 16 Plus"),
    ("iPhone17,5", "iPhone 16e"),
    ("iPhone18,1", "iPhone 17 Pro"),
    ("iPhone18,2", "iPhone 17 Pro Max"),
    ("iPhone18,3", "iPhone 17"),
    ("iPhone18,4", "iPhone Air"),
];
