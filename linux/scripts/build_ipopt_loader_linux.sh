#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_linux_common.sh" require-ipopt-src

BLD="$BUILD_DIR/ipopt_loader"
LOG="$LOG_DIR/build_ipopt_loader.log"

rm -rf "$BLD"
mkdir -p "$BLD" "$IPOPT_LOADER_PREFIX"
cd "$BLD"
exec > >(tee "$LOG") 2>&1

echo "IPOPT loader-enabled build started: $(date)"
echo "Install prefix: $IPOPT_LOADER_PREFIX"
echo "SPRAL is intentionally excluded from this Linux build."

bash "$IPOPT_SRC/configure" --prefix="$IPOPT_LOADER_PREFIX" \
  --enable-static=yes --enable-shared=no --disable-java --disable-pardisomkl \
  --enable-linear-solver-loader --without-asl --without-hsl \
  CC="$CC" CXX="$CXX" FC="$FC" F77="$F77" \
  CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC -std=gnu++11" \
  FCFLAGS="-O2 -fPIC -std=legacy -fallow-argument-mismatch" \
  --with-lapack-lflags="$OPENBLAS_LIBFILE $OPENBLAS_EXTRA_LIBS" \
  --with-mumps-cflags="-I$MUMPS/include/coin-or/mumps -I$METIS/include -I$GKLIB/include" \
  --with-mumps-lflags="$MUMPS/lib/libcoinmumps.a $METIS_LIBFILE $GKLIB_LIBFILE $METIS_EXTRA_LIBS $OPENBLAS_LIBFILE $OPENBLAS_EXTRA_LIBS"

make -j"$JOBS"
make install

echo "IPOPT loader-enabled build finished: $(date)"
find "$IPOPT_LOADER_PREFIX" -maxdepth 4 -type f -printf "%p %s\n" | sort | sed -n '1,120p'
