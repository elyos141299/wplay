// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: dua fungsi ini dipindahkan apa adanya dari src/utils.rs
// iDescriptor v0.6.1 (di sana namanya force_load_gst_gl dan
// qvariant_to_ptr). File utils upstream isinya 1.200+ baris fitur
// iDevice; wPlay cuma butuh dua fungsi GStreamer/Qt ini.

use cpp::*;
use qmetaobject::prelude::*;

//FIXME: this may be called multiple times?
pub fn force_load_gst_gl() -> bool {
    /*
    need to load qml6glsink in order
    to make Qt6GLVideoItem available on qml side
    */
    cpp!(unsafe [] -> bool as "bool"{
        gst_init(nullptr,nullptr);
        // GstElement *pipeline = gst_pipeline_new (NULL);
        // GstElement *src = gst_element_factory_make ("videotestsrc", NULL);
        // GstElement *glupload = gst_element_factory_make ("glupload", NULL);
        GstElement *sink = gst_element_factory_make ("qml6glsink", NULL);
        if (!sink) {
            return false;
        }

        gst_object_unref(sink);

        return true;
    })
}

pub fn qvariant_to_ptr(item: QVariant) -> usize {
    cpp::cpp!(unsafe [item as "QVariant"] -> usize as "uintptr_t" {
        QObject* o = item.value<QObject *>();
        if (!o) return 0;

        // better do this
        QQuickItem* q = qobject_cast<QQuickItem*>(o);
        if (!q) return 0;

        return reinterpret_cast<uintptr_t>(q);
    })
}
