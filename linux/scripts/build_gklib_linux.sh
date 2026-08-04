#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_linux_common.sh"

SRC="$SRC_DIR/GKlib-src"
BLD="$BUILD_DIR/gklib"
LOG="$LOG_DIR/build_gklib.log"

rm -rf "$BLD"
mkdir -p "$BLD" "$GKLIB/lib" "$GKLIB/include"
exec > >(tee "$LOG") 2>&1

echo "GKlib build started: $(date)"
cmake -S "$SRC" -B "$BLD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$GKLIB" \
  -DCMAKE_C_FLAGS="-std=gnu99 -fPIC" \
  -DSHARED=OFF \
  -DPCRE=OFF \
  -DHAVE_REGEX_H=TRUE \
  -DGKLIB_BUILD_APPS=OFF
cmake --build "$BLD" --target GKlib --parallel "$JOBS"
cp -f "$BLD/libGKlib.a" "$GKLIB/lib/libGKlib.a"
cp -f "$SRC/include"/*.h "$GKLIB/include/"
echo "GKlib build finished: $(date)"
ls -lh "$GKLIB/lib/libGKlib.a" "$GKLIB/include/GKlib.h"
