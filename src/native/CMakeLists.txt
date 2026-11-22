cmake_minimum_required(VERSION 3.16)
project(wplay_native CXX C)

# wPlay: versi kecil dari src/native/CMakeLists.txt iDescriptor v0.6.1.
# Peran lapisan native di wPlay cuma satu: merakit UxPlay (submodule
# lib/uxplay) jadi library statis dan menempelkannya ke aplikasi Rust.
# bridge.cpp / networkdeviceprovider / systemappearance / layanan
# dnssd-avahi milik iDescriptor TIDAK ikut — itu fitur manajemen
# iDevice, bukan AirPlay (UxPlay mengurus penemuan perangkatnya
# sendiri lewat Bonjour/Avahi di dalam library-nya).

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(WIN32)
    set(PKG_CONFIG_EXECUTABLE "C:/msys64/mingw64/bin/pkg-config.exe" CACHE FILEPATH "" FORCE)
    set(ENV{PKG_CONFIG_PATH} "C:/msys64/mingw64/lib/pkgconfig;$ENV{PKG_CONFIG_PATH}")
elseif(APPLE)
    set(ENV{PKG_CONFIG_PATH} "/usr/local/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
else()
    set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig")
    # this var is respected by uxplay
    set(NO_X11_DEPS ON)
endif()

find_package(PkgConfig REQUIRED)

# ---------------------------------------------------------------------------
# Qt6
# ---------------------------------------------------------------------------
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
if(UNIX AND NOT APPLE)
    find_package(Qt6 REQUIRED COMPONENTS DBus)
endif()
set(CMAKE_AUTOMOC ON)

# ---------------------------------------------------------------------------
# FFmpeg (dibutuhkan UxPlay/renderers; libheif milik bridge galeri
# iDescriptor tidak dipakai wPlay, jadi tidak dicari di sini)
# ---------------------------------------------------------------------------
pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
pkg_check_modules(AVCODEC  REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(AVUTIL   REQUIRED IMPORTED_TARGET libavutil)
pkg_check_modules(SWSCALE  REQUIRED IMPORTED_TARGET libswscale)

# ---------------------------------------------------------------------------
# GStreamer
# ---------------------------------------------------------------------------
pkg_check_modules(GST       REQUIRED IMPORTED_TARGET gstreamer-1.0)
pkg_check_modules(GST_APP   REQUIRED IMPORTED_TARGET gstreamer-app-1.0)
pkg_check_modules(GST_VIDEO REQUIRED IMPORTED_TARGET gstreamer-video-1.0)
pkg_check_modules(GST_AUDIO REQUIRED IMPORTED_TARGET gstreamer-audio-1.0)

# ---------------------------------------------------------------------------
# glib / gobject / openssl / plist
# ---------------------------------------------------------------------------
pkg_check_modules(GLIB    REQUIRED IMPORTED_TARGET glib-2.0)
pkg_check_modules(GOBJECT REQUIRED IMPORTED_TARGET gobject-2.0)
pkg_check_modules(OPENSSL REQUIRED IMPORTED_TARGET openssl)
pkg_check_modules(PLIST   REQUIRED IMPORTED_TARGET libplist-2.0)

# ---------------------------------------------------------------------------
# Platform-specific service discovery (untuk UxPlay)
# ---------------------------------------------------------------------------
if(APPLE)
    find_library(CORE_SERVICES_FRAMEWORK CoreServices REQUIRED)
elseif(WIN32)
    if(DEFINED ENV{BONJOUR_SDK})
        set(BONJOUR_SDK_DIR "$ENV{BONJOUR_SDK}")
    else()
        set(BONJOUR_SDK_DIR "C:/Program Files/Bonjour SDK")
    endif()
    if(NOT EXISTS "${BONJOUR_SDK_DIR}/Include/dns_sd.h")
        message(FATAL_ERROR "Bonjour SDK not found at ${BONJOUR_SDK_DIR}. Set BONJOUR_SDK env var.")
    endif()
else()
    pkg_check_modules(AVAHI        REQUIRED IMPORTED_TARGET avahi-client)
    pkg_check_modules(AVAHI_COMPAT REQUIRED IMPORTED_TARGET avahi-compat-libdns_sd)
endif()

# ---------------------------------------------------------------------------
# uxplay (submodule lib/uxplay, commit terkunci — lihat .gitmodules)
# ---------------------------------------------------------------------------
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../lib/uxplay/CMakeLists.txt")
    message(FATAL_ERROR "lib/uxplay is empty. Run scripts/fetch-uxplay.sh first (or: git submodule update --init lib/uxplay).")
endif()
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../lib/uxplay uxplay_build)

# ---------------------------------------------------------------------------
# Static library — penerus peran cpp_bridge, tanpa sumber iDevice
# ---------------------------------------------------------------------------
add_library(wplay_native STATIC wplay_native.cpp)
set_target_properties(wplay_native PROPERTIES AUTOMOC ON)

target_link_libraries(wplay_native PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    PkgConfig::AVFORMAT
    PkgConfig::AVCODEC
    PkgConfig::AVUTIL
    PkgConfig::SWSCALE
    PkgConfig::GST
    PkgConfig::GST_APP
    PkgConfig::GST_VIDEO
    PkgConfig::GST_AUDIO
    PkgConfig::GLIB
    PkgConfig::GOBJECT
    PkgConfig::OPENSSL
    PkgConfig::PLIST
    uxplay
    renderers
    airplay
    llhttp
    playfair
)

if(APPLE)
    target_link_libraries(wplay_native PUBLIC ${CORE_SERVICES_FRAMEWORK})
elseif(WIN32)
    target_include_directories(wplay_native PRIVATE "${BONJOUR_SDK_DIR}/Include")
    target_link_libraries(wplay_native PUBLIC "${BONJOUR_SDK_DIR}/Lib/x64/dnssd.lib")
else()
    target_link_libraries(wplay_native PUBLIC
        Qt6::DBus
        PkgConfig::AVAHI
        PkgConfig::AVAHI_COMPAT
    )
endif()
