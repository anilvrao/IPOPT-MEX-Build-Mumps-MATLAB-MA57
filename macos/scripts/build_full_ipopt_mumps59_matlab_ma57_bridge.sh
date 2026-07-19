#!/usr/bin/env bash
# Full experimental Apple Silicon IPOPT MATLAB MEX rebuild:
#   - Ipopt 3.14.19 rebuilt against MUMPS 5.9.0 headers/libraries
#   - MUMPS 5.9.0 from official source via current Coin-OR ThirdParty-Mumps
#   - existing source-built OpenBLAS, METIS, SPRAL, and hwloc archives
#   - internal MATLAB MA57 bridge using Ma57TSolverInterface::SetFunctions
#
# This script writes only under ipopt_mumps59_matlab_ma57_bridge_experiment.

set -euo pipefail

export MACOSX_DEPLOYMENT_TARGET=12.0
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if [[ -z "${IPOPT_MEX_WORK_ROOT:-}" ]]; then
  echo "Set IPOPT_MEX_WORK_ROOT to the parent directory containing the required source/build trees." >&2
  exit 1
fi

ROOT="$IPOPT_MEX_WORK_ROOT"
BASE="${IPOPT_MEX_BASE:-$ROOT/ipopt_spral_mumps_source_mac_build}"
BRIDGE="${IPOPT_MEX_BRIDGE:-$ROOT/ipopt_mac_internal_ma57_bridge_experiment}"
BUILD_ROOT="${IPOPT_MEX_BUILD_ROOT:-$ROOT/ipopt_mumps59_matlab_ma57_bridge_experiment}"

MATLAB="${MATLAB:-/Applications/MATLAB_R2025b.app/bin/matlab}"
IPOPT_SRC_ORIG="$BASE/src/Ipopt-3.14.19"
MEXIPOPT="$BASE/src/mexIPOPT-toolbox"

IPOPT_SRC="$BUILD_ROOT/src/Ipopt-3.14.19-mumps59"
IPOPT_BUILD="$BUILD_ROOT/build/ipopt-mumps59"
IPOPT_INSTALL="$BUILD_ROOT/install/ipopt-mumps59"
HSL_INCLUDE="$BUILD_ROOT/hsl_include"
HSL_STUB="$BUILD_ROOT/hsl_configure_stub.o"
FLAT_DIR="$BUILD_ROOT/flat_full"
FLAT_LIB="$FLAT_DIR/libipopt_mumps59_ma57_callback_guard.a"
MUMPS_FILELIST="$BUILD_ROOT/flat/mumps_objects.filelist"
MEX_BUILD="$BUILD_ROOT/mex-build-full"
MEX_BIN="$MEX_BUILD/bin"

MUMPS_BUILD="$BUILD_ROOT/build/mumps"
MUMPS_INSTALL="$BUILD_ROOT/install/mumps"

OPENBLAS_LIB="$BASE/install/openblas/lib/libopenblas.a"
SPRAL_LIB="$BASE/install/spral/lib/libspral.a"
METIS_LIB="$BASE/install/metis/lib/libmetis.a"
HWLOC_LIB="$BASE/install/hwloc/lib/libhwloc.a"

GCC_ROOT="${GCC_ROOT:-/opt/homebrew/Cellar/gcc/15.2.0_1/lib/gcc/current}"
GFORTRAN="${GFORTRAN:-/opt/homebrew/bin/gfortran}"
GFORTRAN_LIB="$GCC_ROOT/libgfortran.a"
QUADMATH_LIB="$GCC_ROOT/libquadmath.a"
GOMP_LIB="$GCC_ROOT/libgomp.a"
STDCXX_LIB="$GCC_ROOT/libstdc++.a"
ATOMIC_LIB="$GCC_ROOT/libatomic.a"
GCC_LIB="$GCC_ROOT/gcc/aarch64-apple-darwin24/15/libgcc.a"

CC="/usr/bin/clang"
CXX="/usr/bin/clang++"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 8)}"

for required in \
  "$MATLAB" \
  "$IPOPT_SRC_ORIG/configure" \
  "$MEXIPOPT/src/ipopt.cc" \
  "$MUMPS_BUILD/.libs/libcoinmumps.a" \
  "$MUMPS_INSTALL/include/coin-or/mumps/dmumps_c.h" \
  "$MUMPS_FILELIST" \
  "$BRIDGE/patched-ipopt/Algorithm/IpBacktrackingLineSearch.cpp" \
  "$BRIDGE/patched-ipopt/Algorithm/IpIpoptAlg.cpp" \
  "$BRIDGE/patched-ipopt/Algorithm/IpRestoMinC_1Nrm.cpp" \
  "$BRIDGE/patched-ipopt/Algorithm/LinearSolvers/IpSpralSolverInterface.cpp" \
  "$BRIDGE/mex-build/ipopt_setfunctions.cc" \
  "$BRIDGE/mex-build/IpoptInterfaceCommon_safe.cc" \
  "$BRIDGE/mex-build/IpoptInterfaceCommon.hh" \
  "$BRIDGE/mex-build/matlab_ma57_setfunctions_bridge.cpp" \
  "$OPENBLAS_LIB" \
  "$SPRAL_LIB" \
  "$METIS_LIB" \
  "$HWLOC_LIB" \
  "$GFORTRAN" \
  "$GFORTRAN_LIB" \
  "$QUADMATH_LIB" \
  "$GOMP_LIB" \
  "$STDCXX_LIB" \
  "$ATOMIC_LIB" \
  "$GCC_LIB"
do
  if [[ ! -e "$required" ]]; then
    echo "Missing required file: $required" >&2
    exit 1
  fi
done

rm -rf "$IPOPT_SRC" "$IPOPT_BUILD" "$IPOPT_INSTALL" "$HSL_INCLUDE" "$FLAT_DIR" "$MEX_BUILD"
mkdir -p "$BUILD_ROOT/src" "$IPOPT_BUILD" "$IPOPT_INSTALL" "$HSL_INCLUDE" "$FLAT_DIR" "$MEX_BIN"

echo "Preparing patched Ipopt source..."
cp -R "$IPOPT_SRC_ORIG" "$IPOPT_SRC"
cp "$BRIDGE/patched-ipopt/Algorithm/IpBacktrackingLineSearch.cpp" \
  "$IPOPT_SRC/src/Algorithm/IpBacktrackingLineSearch.cpp"
cp "$BRIDGE/patched-ipopt/Algorithm/IpIpoptAlg.cpp" \
  "$IPOPT_SRC/src/Algorithm/IpIpoptAlg.cpp"
cp "$BRIDGE/patched-ipopt/Algorithm/IpRestoMinC_1Nrm.cpp" \
  "$IPOPT_SRC/src/Algorithm/IpRestoMinC_1Nrm.cpp"
cp "$BRIDGE/patched-ipopt/Algorithm/LinearSolvers/IpSpralSolverInterface.cpp" \
  "$IPOPT_SRC/src/Algorithm/LinearSolvers/IpSpralSolverInterface.cpp"

cat > "$HSL_INCLUDE/CoinHslConfig.h" <<'EOF'
#ifndef COINHSL_CONFIG_H
#define COINHSL_CONFIG_H
#define COINHSL_HAS_MA57 1
#endif
EOF

cat > "$BUILD_ROOT/hsl_configure_stub.c" <<'EOF'
char ma27ad_(void)
{
  return 0;
}
EOF
"$CC" -O2 -fPIC -mmacosx-version-min=12.0 -c "$BUILD_ROOT/hsl_configure_stub.c" -o "$HSL_STUB"

OPENBLAS_LFLAGS="$OPENBLAS_LIB $GFORTRAN_LIB $QUADMATH_LIB $GCC_LIB"
MUMPS_CFLAGS="-I$MUMPS_INSTALL/include/coin-or/mumps"
MUMPS_LFLAGS="$MUMPS_BUILD/.libs/libcoinmumps.a $OPENBLAS_LFLAGS $ATOMIC_LIB"
SPRAL_CFLAGS="-I$BASE/install/spral/include"
SPRAL_LFLAGS="$SPRAL_LIB $METIS_LIB $HWLOC_LIB -framework CoreFoundation -framework IOKit $OPENBLAS_LFLAGS $GOMP_LIB $STDCXX_LIB $ATOMIC_LIB"
HSL_CFLAGS="-I$HSL_INCLUDE"
HSL_LFLAGS="$HSL_STUB"

echo "Configuring and building Ipopt against MUMPS 5.9.0..."
pushd "$IPOPT_BUILD" >/dev/null
CC="$CC" CXX="$CXX" FC="$GFORTRAN" F77="$GFORTRAN" \
CFLAGS="-O2 -fPIC -mmacosx-version-min=12.0" \
CXXFLAGS="-O2 -fPIC -mmacosx-version-min=12.0 -DFUNNY_MA57_FINT -fno-c++-static-destructors" \
FCFLAGS="-O2 -fPIC -mmacosx-version-min=12.0" \
LDFLAGS="-Wl,-ld_classic" \
"$IPOPT_SRC/configure" \
  --prefix="$IPOPT_INSTALL" \
  --enable-static=yes \
  --enable-shared=no \
  --disable-java \
  --disable-pardisomkl \
  --disable-linear-solver-loader \
  --without-asl \
  --with-lapack-lflags="$OPENBLAS_LFLAGS" \
  --with-mumps-cflags="$MUMPS_CFLAGS" \
  --with-mumps-lflags="$MUMPS_LFLAGS" \
  --with-spral-cflags="$SPRAL_CFLAGS" \
  --with-spral-lflags="$SPRAL_LFLAGS" \
  --with-hsl-cflags="$HSL_CFLAGS" \
  --with-hsl-lflags="$HSL_LFLAGS"
make -j"$JOBS"
make install
popd >/dev/null

echo "Flattening patched Ipopt objects..."
/usr/bin/libtool -static -o "$FLAT_LIB" $(find "$IPOPT_BUILD/src" -name '*.o')

echo "Writing MATLAB MEX compile driver..."
cp "$BRIDGE/mex-build/ipopt_setfunctions.cc" "$MEX_BUILD/ipopt_setfunctions.cc"
cp "$BRIDGE/mex-build/IpoptInterfaceCommon_safe.cc" "$MEX_BUILD/IpoptInterfaceCommon_safe.cc"
cp "$BRIDGE/mex-build/IpoptInterfaceCommon.hh" "$MEX_BUILD/IpoptInterfaceCommon.hh"
cp "$BRIDGE/mex-build/matlab_ma57_setfunctions_bridge.cpp" "$MEX_BUILD/matlab_ma57_setfunctions_bridge.cpp"
cat > "$MEX_BUILD/ma57_link_stubs.cpp" <<'EOF'
#include "mex.h"

extern "C" {

void ma57ad_()
{
  mexErrMsgIdAndTxt("IpoptMex:Ma57Stub",
                    "Internal error: direct MA57AD symbol was called instead of the MATLAB MA57 bridge.");
}

void ma57bd_()
{
  mexErrMsgIdAndTxt("IpoptMex:Ma57Stub",
                    "Internal error: direct MA57BD symbol was called instead of the MATLAB MA57 bridge.");
}

void ma57cd_()
{
  mexErrMsgIdAndTxt("IpoptMex:Ma57Stub",
                    "Internal error: direct MA57CD symbol was called instead of the MATLAB MA57 bridge.");
}

void ma57ed_()
{
  mexErrMsgIdAndTxt("IpoptMex:Ma57Stub",
                    "Internal error: direct MA57ED symbol was called instead of the MATLAB MA57 bridge.");
}

void ma57id_()
{
  mexErrMsgIdAndTxt("IpoptMex:Ma57Stub",
                    "Internal error: direct MA57ID symbol was called instead of the MATLAB MA57 bridge.");
}

}
EOF

cat > "$MEX_BUILD/compile_ipopt_mex_full_mumps59_matlab_ma57.m" <<EOF
clear functions;
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));

toolbox = '$MEXIPOPT';
installRoot = '$IPOPT_INSTALL';
ipoptSrc = '$IPOPT_SRC';
mexBuild = '$MEX_BUILD';
cd(toolbox);

src = {fullfile(mexBuild,'ipopt_setfunctions.cc'), ...
  fullfile(mexBuild,'IpoptInterfaceCommon_safe.cc'), ...
  fullfile(mexBuild,'matlab_ma57_setfunctions_bridge.cpp'), ...
  fullfile(mexBuild,'ma57_link_stubs.cpp')};

args = [{'-largeArrayDims', ['-I', mexBuild], '-Isrc', ...
  ['-I', fullfile(installRoot,'include','coin-or')], ...
  ['-I', fullfile(ipoptSrc,'src','Algorithm','LinearSolvers')], ...
  '-DOS_MAC', '-output', fullfile(mexBuild,'bin','ipopt')}, src, ...
  {'LDFLAGS=\$LDFLAGS -Wl,-ld_classic -Wl,-no_compact_unwind -Wl,-dead_strip -framework CoreFoundation -framework IOKit -ldl', ...
  'LINKLIBS=\$LINKLIBS -Wl,-force_load,$FLAT_LIB -Wl,-filelist,$MUMPS_FILELIST $SPRAL_LIB $METIS_LIB $HWLOC_LIB $OPENBLAS_LIB $GOMP_LIB $STDCXX_LIB $GFORTRAN_LIB $QUADMATH_LIB $GCC_LIB $ATOMIC_LIB', ...
  'CXXFLAGS=\$CXXFLAGS -Wall -O2 -DFUNNY_MA57_FINT -fno-c++-static-destructors'}];

mex(args{:});

fprintf('Built: %s\\n', fullfile(mexBuild,'bin',['ipopt.',mexext]));
EOF

echo "Compiling MATLAB MEX..."
"$MATLAB" -batch "run('$MEX_BUILD/compile_ipopt_mex_full_mumps59_matlab_ma57.m')"

echo
echo "Built full experimental MEX:"
echo "  $MEX_BIN/ipopt.mexmaca64"
echo
otool -L "$MEX_BIN/ipopt.mexmaca64"
