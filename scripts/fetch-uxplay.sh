#!/usr/bin/env bash
# Ambil UxPlay di commit yang persis dipakai iDescriptor v0.6.1
# ke lib/uxplay. Jalan di Linux dan di MSYS2 MinGW64 (Windows).
set -euo pipefail

UXPLAY_COMMIT="eaca2458946d8a283df3b872f25c6b7cc98be411"
UXPLAY_URL="https://github.com/iDescriptor/uxplay.git"

cd "$(dirname "$0")/.."

if [ -f lib/uxplay/CMakeLists.txt ]; then
    echo "lib/uxplay sudah terisi, tidak ada yang dilakukan."
    exit 0
fi

# Buang README placeholder bila foldernya cuma berisi itu.
if [ -d lib/uxplay ] && [ "$(ls -A lib/uxplay)" = "README.md" ]; then
    rm -rf lib/uxplay
fi

git clone "$UXPLAY_URL" lib/uxplay
git -C lib/uxplay checkout "$UXPLAY_COMMIT"
echo "UxPlay siap di lib/uxplay @ $UXPLAY_COMMIT"
