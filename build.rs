// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: build.rs ini diadaptasi dari build.rs iDescriptor v0.6.1.
// Alurnya sama persis: (1) CMake merakit lapisan native (di wPlay:
// src/native -> library wplay_native + UxPlay), (2) cpp_build
// mengompilasi blok cpp! di kode Rust, (3) library statis ditempel
// dalam urutan dependensi. Yang dibuang dari upstream: embed
// resource .rc/ikon iDescriptor, terjemahan, jembatan macOS
// (mac_window), dan probe libheif (milik fitur galeri).

use std::env;
use std::path::PathBuf;

fn main() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();

    println!("cargo:rerun-if-changed=src/native/CMakeLists.txt");
    println!("cargo:rerun-if-changed=src/native/wplay_native.cpp");
    println!("cargo:rerun-if-changed=lib/uxplay/uxplay.h");
    println!("cargo:rerun-if-changed=lib/uxplay/uxplay.cpp");

    let qt_include_path = env::var("DEP_QT_INCLUDE_PATH").unwrap();
    let qt_library_path = env::var("DEP_QT_LIBRARY_PATH").unwrap();
    let qt_version = env::var("DEP_QT_VERSION").unwrap();

    // ------------------------------------------------------------------
    // Build lapisan native (UxPlay) via CMake
    // ------------------------------------------------------------------
    let mut cmake_config = cmake::Config::new("src/native");
    cmake_config
        .build_target("wplay_native")
        .define("CMAKE_BUILD_TYPE", "Debug")
        .define("CMAKE_PREFIX_PATH", &qt_library_path);
    let out = cmake_config.build();

    let build_dir = out.join("build");

    // wplay_native
    println!("cargo:rustc-link-search=native={}", build_dir.display());

    // uxplay sub-libs built inside the cmake tree
    for sub in &[
        "uxplay_build",
        "uxplay_build/lib",
        "uxplay_build/renderers",
        "uxplay_build/lib/llhttp",
        "uxplay_build/lib/playfair",
    ] {
        println!(
            "cargo:rustc-link-search=native={}/{}",
            build_dir.display(),
            sub
        );
    }

    // ------------------------------------------------------------------
    // cpp_build — scans the crate root and compiles its cpp! macro modules
    // ------------------------------------------------------------------
    let mut config = cpp_build::Config::new();
    // GCC 16 diagnoses a SFINAE pattern used by the Qt headers. This is
    // third-party compatibility noise, so suppress it only when supported.
    config.flag_if_supported("-Wno-sfinae-incomplete");

    for f in env::var("DEP_QT_COMPILE_FLAGS")
        .unwrap()
        .split_terminator(';')
    {
        config.flag(f);
    }

    let mut public_include = |name: &str| {
        if target_os == "macos" {
            config.include(format!("{}/{}.framework/Headers/", qt_library_path, name));
        }
        config.include(format!("{}/{}", qt_include_path, name));
    };
    public_include("QtCore");
    public_include("QtGui");
    public_include("QtQuick");
    public_include("QtQml");
    public_include("QtQuickControls2");
    public_include("QtWidgets");
    if target_os == "linux" {
        public_include("QtDBus");
    }

    let mut private_include = |name: &str| {
        if target_os == "macos" {
            config.include(format!(
                "{}/{}.framework/Headers/{}",
                qt_library_path, name, qt_version
            ));
            config.include(format!(
                "{}/{}.framework/Headers/{}/{}",
                qt_library_path, name, qt_version, name
            ));
        }
        config
            .include(format!("{}/{}/{}", qt_include_path, name, qt_version))
            .include(format!(
                "{}/{}/{}/{}",
                qt_include_path, name, qt_version, name
            ));
    };
    private_include("QtCore");
    private_include("QtQuick");
    private_include("QtQml");

    let mut add_pkg_includes = |pkg: &str| {
        if let Ok(lib) = pkg_config::Config::new().cargo_metadata(false).probe(pkg) {
            for p in lib.include_paths {
                config.include(p);
            }
        }
    };
    add_pkg_includes("gstreamer-1.0");
    add_pkg_includes("gstreamer-app-1.0");
    add_pkg_includes("gstreamer-video-1.0");
    add_pkg_includes("gstreamer-audio-1.0");
    add_pkg_includes("glib-2.0");
    add_pkg_includes("gobject-2.0");

    if target_os == "macos" {
        config.flag(&format!("-F{}", qt_library_path));
    }

    if target_os == "windows" {
        // need to include Bonjour SDK headers for dnssd.h
        let bonjour_sdk = env::var("BONJOUR_SDK")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("C:/Program Files/Bonjour SDK"));
        config.include(bonjour_sdk.join("Include"));
    }

    config.include(&qt_include_path).build("src/main.rs");

    // Static libraries must be emitted after cpp_build's generated archive and
    // in dependency order: wplay_native references uxplay/renderers/airplay.
    println!("cargo:rustc-link-lib=static=wplay_native");
    for lib in &["uxplay", "renderers", "airplay", "llhttp", "playfair"] {
        println!("cargo:rustc-link-lib=static={}", lib);
    }

    // These are deps of the static libs (uxplay/airplay/wplay_native) that the
    // Rust linker must resolve explicitly since static libs don't embed deps.
    // (Upstream also probes libheif here; wPlay does not use it.)
    pkg_config::Config::new().probe("openssl").unwrap();
    pkg_config::Config::new().probe("libplist-2.0").unwrap();
    pkg_config::Config::new().probe("glib-2.0").unwrap();
    pkg_config::Config::new().probe("gobject-2.0").unwrap();

    if target_os == "linux" {
        pkg_config::Config::new().probe("avahi-client").unwrap();
        pkg_config::Config::new()
            .probe("avahi-compat-libdns_sd")
            .unwrap();
        pkg_config::Config::new().probe("Qt6DBus").unwrap();
    }

    // FFmpeg
    if let Ok(ffmpeg_dir) = env::var("FFMPEG_DIR") {
        println!("cargo:rustc-link-search={}/lib", ffmpeg_dir);
        for lib in &["avformat", "avcodec", "avutil", "swscale"] {
            println!("cargo:rustc-link-lib={}", lib);
        }
    } else {
        let _ = pkg_config::Config::new().probe("libavformat");
        let _ = pkg_config::Config::new().probe("libavcodec");
        let _ = pkg_config::Config::new().probe("libavutil");
        let _ = pkg_config::Config::new().probe("libswscale");
    }

    // GStreamer
    for pkg in &[
        "gstreamer-1.0",
        "gstreamer-app-1.0",
        "gstreamer-video-1.0",
        "gstreamer-audio-1.0",
    ] {
        pkg_config::Config::new().probe(pkg).unwrap();
    }

    // Qt (macOS needs framework search path; Linux/Windows via pkg-config)
    if target_os == "macos" {
        println!("cargo:rustc-link-search=framework={}", qt_library_path);
        for fw in &["QtCore", "QtGui", "QtQml", "QtQuick", "QtQuickControls2"] {
            println!("cargo:rustc-link-lib=framework={}", fw);
        }
    }

    // Windows: Bonjour
    if target_os == "windows" {
        let bonjour_sdk = env::var("BONJOUR_SDK")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("C:/Program Files/Bonjour SDK"));
        println!(
            "cargo:rustc-link-arg={}",
            bonjour_sdk.join("Lib/x64/dnssd.lib").display()
        );

        // wPlay (Phase 3, run #6): library sistem Windows yang
        // dibutuhkan kode UxPlay tapi tidak pernah dideklarasikan
        // untuk linker Rust (CMake-nya UxPlay menyebut iphlpapi +
        // ws2_32 untuk target airplay-nya sendiri, tapi daftar itu
        // tidak diteruskan ke link final via cargo):
        // - advapi32: CryptAcquireContext/CryptGenRandom/
        //   CryptReleaseContext di lib/uxplay/lib/srp.c
        // - iphlpapi: GetAdaptersAddresses di lib/uxplay/uxplay.cpp
        // - ws2_32/wsock32: socket Winsock yang dipakai UxPlay
        for lib in &["advapi32", "iphlpapi", "ws2_32", "wsock32"] {
            println!("cargo:rustc-link-lib={}", lib);
        }
    }
}
