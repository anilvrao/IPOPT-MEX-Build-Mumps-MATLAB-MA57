#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ROOT=${ROOT:-$SCRIPT_DIR}
SRC_DIR=${SRC_DIR:?Set SRC_DIR to the directory containing the staged MEX sources}
BUILD_DIR=${BUILD_DIR:-$ROOT/build-linux}
INSTALL_DIR=${INSTALL_DIR:-$ROOT/install-linux}
LOG_DIR=${LOG_DIR:-$ROOT/logs-linux}

JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)}

CC=${CC:-/usr/bin/gcc-12}
CXX=${CXX:-/usr/bin/g++-12}
FC=${FC:-/usr/bin/gfortran-12}
F77=${F77:-/usr/bin/gfortran-12}
AR=${AR:-/usr/bin/ar}
RANLIB=${RANLIB:-/usr/bin/ranlib}

resolve_compiler_lib() {
  local compiler="$1"
  local libname="$2"
  local resolved
  resolved="$("$compiler" -print-file-name="$libname" 2>/dev/null || true)"
  if [ -n "$resolved" ] && [ "$resolved" != "$libname" ]; then
    printf '%s' "$resolved"
  else
    printf '%s' "-l${libname#lib}"
  fi
}

GFORTRAN_LIB=${GFORTRAN_LIB:-$(resolve_compiler_lib "$FC" libgfortran.so)}
QUADMATH_LIB=${QUADMATH_LIB:-$(resolve_compiler_lib "$FC" libquadmath.so)}
GCC_S_LIB=${GCC_S_LIB:-$(resolve_compiler_lib "$CC" libgcc_s.so)}

OPENBLAS_EXTRA_LIBS=${OPENBLAS_EXTRA_LIBS:-$GFORTRAN_LIB $QUADMATH_LIB $GCC_S_LIB -lm -lpthread}

OPENBLAS=${OPENBLAS:-$INSTALL_DIR/openblas}
OPENBLAS_LIBFILE=${OPENBLAS_LIBFILE:-$OPENBLAS/lib/libopenblas.a}
USE_EXISTING_OPENBLAS_ROOT=${USE_EXISTING_OPENBLAS_ROOT:-}
GKLIB=${GKLIB:-$INSTALL_DIR/gklib}
METIS=${METIS:-$INSTALL_DIR/metis}
MUMPS=${MUMPS:-$INSTALL_DIR/mumps}
IPOPT_LOADER_PREFIX=${IPOPT_LOADER_PREFIX:-$INSTALL_DIR/ipopt_loader}

resolve_built_lib() {
  local root="$1"
  local stem="$2"
  if [ -f "$root/lib/${stem}.a" ]; then
    printf '%s' "$root/lib/${stem}.a"
  elif [ -f "$root/lib/${stem}.so" ]; then
    printf '%s' "$root/lib/${stem}.so"
  else
    printf '%s' "$root/lib/${stem}.a"
  fi
}

GKLIB_LIBFILE=${GKLIB_LIBFILE:-$(resolve_built_lib "$GKLIB" libGKlib)}
METIS_LIBFILE=${METIS_LIBFILE:-$(resolve_built_lib "$METIS" libmetis)}
METIS_EXTRA_LIBS=${METIS_EXTRA_LIBS:--lm}

mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$LOG_DIR"

if [ "${1-}" = "require-ipopt-src" ]; then
  : "${IPOPT_SRC:?Set IPOPT_SRC to the unpacked IPOPT source tree before building IPOPT.}"
fi
