#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_linux_common.sh"

SRC="$SRC_DIR/OpenBLAS-0.3.33"
STAGE="$BUILD_DIR/openblas-src"
LOG="$LOG_DIR/build_openblas.log"

exec > >(tee "$LOG") 2>&1

echo "OpenBLAS build started: $(date)"
"$CC" --version | head -n 1
"$FC" --version | head -n 1
rm -rf "$STAGE"
mkdir -p "$STAGE"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SRC/" "$STAGE/"
else
  cp -a "$SRC/." "$STAGE/"
fi

# Some transferred source trees lose executable bits on helper scripts.
chmod +x "$STAGE"/c_check "$STAGE"/f_check

cd "$STAGE"
make clean || true
make -j"$JOBS" \
  NO_SHARED=1 USE_THREAD=0 DYNAMIC_ARCH=1 BINARY=64 NO_LAPACKE=1 \
  CC="$CC" HOSTCC="$CC" FC="$FC" AR="$AR" RANLIB="$RANLIB"
make PREFIX="$OPENBLAS" NO_SHARED=1 USE_THREAD=0 NO_LAPACKE=1 install
echo "OpenBLAS build finished: $(date)"
ls -lh "$OPENBLAS/lib"
