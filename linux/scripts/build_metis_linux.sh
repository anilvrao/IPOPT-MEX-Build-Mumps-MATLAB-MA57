#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_linux_common.sh"

SRC="$SRC_DIR/metis-src"
STAGE="$BUILD_DIR/metis-src"
LOG="$LOG_DIR/build_metis.log"

rm -rf "$STAGE"
mkdir -p "$METIS"
exec > >(tee "$LOG") 2>&1

echo "METIS build started: $(date)"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SRC/" "$STAGE/"
else
  cp -a "$SRC" "$STAGE"
fi

cd "$STAGE"
make distclean || true
make config prefix="$METIS" cc="$CC" gklib_path="$GKLIB"
cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX="$METIS" \
  -DGKLIB_PATH="$GKLIB" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
  -DCMAKE_C_FLAGS="-O3 -fPIC -fno-lto" \
  -DSHARED=OFF
cmake --build build --target metis --parallel "$JOBS"
mkdir -p "$METIS/lib" "$METIS/include"
cp -f "$STAGE/build/libmetis/libmetis.a" "$METIS/lib/libmetis.a"
cp -f "$STAGE/build/xinclude/metis.h" "$METIS/include/metis.h"
echo "METIS build finished: $(date)"
find "$METIS" -maxdepth 3 -type f -printf "%p %s\n" | sort
