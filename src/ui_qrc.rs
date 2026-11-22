// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: pendaftaran QML ke Qt resource system (qrc), meniru pola
// src/ui_qrc.rs iDescriptor v0.6.1 — hanya satu file, jendela wPlay.
// Modul ini hanya dikompilasi di build rilis (lihat main.rs).

use qmetaobject::qrc;

qrc!(pub qml,
    "/" {
        "src/ui/Main.qml",
    }
);
