// wPlay native layer — intentionally almost empty.
//
// In iDescriptor v0.6.1 this CMake project also compiles bridge.cpp
// (device discovery, file dialogs, gallery helpers, ...). None of that
// belongs to AirPlay, so wPlay drops it. This translation unit only
// exists so CMake has a source file for the wplay_native static
// library; the library's real job is linking UxPlay (uxplay,
// renderers, airplay, llhttp, playfair) plus Qt/GStreamer/FFmpeg
// into the Rust binary — the same role cpp_bridge played upstream.
//
// The UxPlay entry points used by the Rust side (init_uxplay,
// uxplay_cleanup, uxplay_set_audio_volume, set_uxplay_gl_callbacks)
// are declared in lib/uxplay/uxplay.h and defined by the uxplay
// library itself.
