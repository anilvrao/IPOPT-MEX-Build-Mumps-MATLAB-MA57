#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${IPOPT_SRC:?Set IPOPT_SRC to the Ipopt source directory.}"
: "${MUMPS_ROOT:?Set MUMPS_ROOT to the MUMPS install/build directory.}"

IPOPT_SRC="$(cygpath -u "$IPOPT_SRC" 2>/dev/null || echo "$IPOPT_SRC")"
MUMPS_ROOT="$(cygpath -u "$MUMPS_ROOT" 2>/dev/null || echo "$MUMPS_ROOT")"
MKL_ROOT="${MKL_ROOT:-C:/PROGRA~2/Intel/oneAPI/mkl/latest}"

BLD="$ROOT/build/ipopt_msvc_ifx_mumps_ma57"
PREFIX="$ROOT/install/ipopt_msvc_ifx_mumps_ma57"
HSL="$ROOT/install/hsl_stubs"
MKLSEQ="-LIBPATH:$MKL_ROOT/lib mkl_intel_lp64.lib mkl_sequential.lib mkl_core.lib"

rm -rf "$BLD" "$PREFIX" "$HSL"
mkdir -p "$BLD" "$PREFIX" "$ROOT/build" "$ROOT/logs" "$ROOT/hsl_include" "$HSL/lib"
cp "$ROOT/src/CoinHslConfig.h" "$ROOT/hsl_include/CoinHslConfig.h"

exec > >(tee "$ROOT/logs/configure_ipopt_static_msvc_ifx_mumps_ma57.log") 2>&1

echo "IPOPT configure started: $(date)"
echo "ROOT=$ROOT"
echo "IPOPT_SRC=$IPOPT_SRC"
echo "MUMPS_ROOT=$MUMPS_ROOT"
echo "MKL_ROOT=$MKL_ROOT"
echo "CC=$(command -v icx)"
echo "CXX=$(command -v icx)"
echo "FC=$(command -v ifx)"
echo "lib=$(command -v lib || true)"

HSL_OBJ_WIN="$(cygpath -w "$ROOT/build/hsl_link_stubs.obj")"
HSL_LIB_WIN="$(cygpath -w "$ROOT/install/hsl_stubs/lib/ipopt_mex_hsl_link_stubs.lib")"
icx -c -O2 -MD -EHsc "$ROOT/src/hsl_link_stubs.cpp" -Fo"$HSL_OBJ_WIN"
lib -nologo -out:"$HSL_LIB_WIN" "$HSL_OBJ_WIN"

cd "$BLD"

"$IPOPT_SRC/configure" --prefix="$PREFIX" \
  --enable-static=yes --enable-shared=no --disable-java --disable-pardisomkl \
  --disable-linear-solver-loader --without-asl \
  CC=icx CXX=icx FC=ifx F77=ifx \
  CFLAGS="-O2 -MD" CXXFLAGS="-O2 -MD -EHsc -Xclang -fcxx-exceptions -Xclang -fexceptions" FCFLAGS="-O2 -MD -fpp" \
  --with-lapack-lflags="$MKLSEQ" \
  --with-hsl-cflags="-I$ROOT/hsl_include" \
  --with-hsl-lflags="$HSL/lib/ipopt_mex_hsl_link_stubs.lib" \
  --with-mumps-cflags="-I$MUMPS_ROOT/include -I$MUMPS_ROOT/libseq" \
  --with-mumps-lflags="$MUMPS_ROOT/lib/libdmumps.lib $MUMPS_ROOT/lib/libmumps_common.lib $MUMPS_ROOT/lib/libpord.lib $MUMPS_ROOT/lib/libmpiseq.lib $MKLSEQ"

echo "IPOPT configure finished: $(date)"
