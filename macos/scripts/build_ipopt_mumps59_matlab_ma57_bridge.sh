#!/usr/bin/env bash
# Experimental Apple Silicon IPOPT MATLAB MEX:
#   - proven patched Ipopt/MEX interface from the internal MATLAB MA57 bridge build
#   - MUMPS 5.9.0 rebuilt from official source
#   - existing source-built OpenBLAS/METIS/SPRAL/hwloc runtime archives from the
#     prior Mac source build, because the patched Ipopt archive still contains
#     SPRAL solver objects even though the MEX guard exposes only mumps/ma57.
#
# This is a sandbox build. It does not modify the R7 distribution.

set -euo pipefail

export MACOSX_DEPLOYMENT_TARGET=12.0
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if [[ -z "${GPOPS_IPOPT_WORK_ROOT:-}" ]]; then
  echo "Set GPOPS_IPOPT_WORK_ROOT to the parent directory containing the required source/build trees." >&2
  exit 1
fi

ROOT="$GPOPS_IPOPT_WORK_ROOT"
BASE="${GPOPS_IPOPT_BASE:-$ROOT/ipopt_spral_mumps_source_mac_build}"
BRIDGE="${GPOPS_IPOPT_BRIDGE:-$ROOT/ipopt_mac_internal_ma57_bridge_experiment}"
BUILD_ROOT="${GPOPS_IPOPT_BUILD_ROOT:-$ROOT/ipopt_mumps59_matlab_ma57_bridge_experiment}"

MATLAB="${MATLAB:-/Applications/MATLAB_R2025b.app/bin/matlab}"
MUMPS_TARBALL="$BUILD_ROOT/MUMPS_5.9.0.tar.gz"
MUMPS_SHA256_EXPECTED="02c6efdb91749ec0f82351d40f3f860547272a1eb1d899126a4265b4d6bcc4ca"

TP_ORIG="$BUILD_ROOT/ThirdParty-Mumps-latest"
TP_SRC="$BUILD_ROOT/src/ThirdParty-Mumps"
MUMPS_BUILD="$BUILD_ROOT/build/mumps"
MUMPS_INSTALL="$BUILD_ROOT/install/mumps"
FLAT_DIR="$BUILD_ROOT/flat"
MUMPS_OBJECTS="$FLAT_DIR/mumps_objects"
MUMPS_FILELIST="$FLAT_DIR/mumps_objects.filelist"
MEX_BUILD="$BUILD_ROOT/mex-build"
MEX_BIN="$MEX_BUILD/bin"

OPENBLAS_LIB="$BASE/install/openblas/lib/libopenblas.a"
SPRAL_LIB="$BASE/install/spral/lib/libspral.a"
METIS_LIB="$BASE/install/metis/lib/libmetis.a"
HWLOC_LIB="$BASE/install/hwloc/lib/libhwloc.a"
IPOPT_INSTALL="$BASE/install/ipopt"
IPOPT_SRC="$BASE/src/Ipopt-3.14.19"
MEXIPOPT="$BASE/src/mexIPOPT-toolbox"
PATCHED_IPOPT_LIB="$BRIDGE/mex-build/libipopt_flat_ma57_callback_guard.a"

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
  "$MUMPS_TARBALL" \
  "$TP_ORIG/configure" \
  "$MEXIPOPT/src/ipopt.cc" \
  "$IPOPT_INSTALL/include/coin-or/IpoptConfig.h" \
  "$IPOPT_SRC/src/Algorithm/LinearSolvers/IpMa57TSolverInterface.hpp" \
  "$PATCHED_IPOPT_LIB" \
  "$BRIDGE/mex-build/ipopt_setfunctions.cc" \
  "$BRIDGE/mex-build/IpoptInterfaceCommon_safe.cc" \
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

actual_sha="$(shasum -a 256 "$MUMPS_TARBALL" | awk '{print $1}')"
if [[ "$actual_sha" != "$MUMPS_SHA256_EXPECTED" ]]; then
  echo "MUMPS tarball checksum mismatch." >&2
  echo "Expected: $MUMPS_SHA256_EXPECTED" >&2
  echo "Actual:   $actual_sha" >&2
  exit 1
fi

mkdir -p "$BUILD_ROOT/src" "$BUILD_ROOT/build" "$BUILD_ROOT/install" "$FLAT_DIR" "$MEX_BIN"

echo "Preparing Coin-OR ThirdParty-Mumps wrapper with MUMPS 5.9.0..."
rm -rf "$TP_SRC" "$MUMPS_BUILD" "$MUMPS_INSTALL" "$MUMPS_OBJECTS" "$MUMPS_FILELIST"
cp -R "$TP_ORIG" "$TP_SRC"
rm -rf "$TP_SRC/MUMPS"
tar -xzf "$MUMPS_TARBALL" -C "$TP_SRC"
mv "$TP_SRC/MUMPS_5.9.0" "$TP_SRC/MUMPS"

pushd "$TP_SRC" >/dev/null
if [[ -f MUMPS/libseq/mpi.h && ! -f MUMPS/libseq/mumps_mpi.h ]]; then
  if patch -p0 < mumps_mpi.patch; then
    mv MUMPS/libseq/mpi.h MUMPS/libseq/mumps_mpi.h
  else
    echo "mumps_mpi.patch did not apply cleanly; trying compatibility rename only." >&2
    git checkout -- MUMPS >/dev/null 2>&1 || true
    mv MUMPS/libseq/mpi.h MUMPS/libseq/mumps_mpi.h
  fi
fi
popd >/dev/null

echo "Building MUMPS 5.9.0 through ThirdParty-Mumps..."
mkdir -p "$MUMPS_BUILD" "$MUMPS_INSTALL"
pushd "$MUMPS_BUILD" >/dev/null
CC="$CC" FC="$GFORTRAN" F77="$GFORTRAN" \
CFLAGS="-O2 -fPIC -mmacosx-version-min=12.0" \
FCFLAGS="-O2 -fPIC -mmacosx-version-min=12.0" \
"$TP_SRC/configure" \
  --prefix="$MUMPS_INSTALL" \
  --enable-static=yes \
  --enable-shared=no \
  --disable-openmp \
  --with-pic \
  --with-precision=double \
  --with-lapack-lflags="$OPENBLAS_LIB $GFORTRAN_LIB $QUADMATH_LIB $GCC_LIB" \
  --without-metis
make -j"$JOBS"
make install
popd >/dev/null

echo "Flattening MUMPS 5.9.0 objects for MEX link..."
mkdir -p "$MUMPS_OBJECTS"
pushd "$MUMPS_OBJECTS" >/dev/null
ar -x "$MUMPS_BUILD/.libs/libcoinmumps.a"
find "$MUMPS_OBJECTS" -name '*.o' | sort > "$MUMPS_FILELIST"
popd >/dev/null

echo "Writing MATLAB MEX compile driver..."
cp "$BRIDGE/mex-build/ipopt_setfunctions.cc" "$MEX_BUILD/ipopt_setfunctions.cc"
cp "$BRIDGE/mex-build/IpoptInterfaceCommon_safe.cc" "$MEX_BUILD/IpoptInterfaceCommon_safe.cc"
cp "$BRIDGE/mex-build/IpoptInterfaceCommon.hh" "$MEX_BUILD/IpoptInterfaceCommon.hh"
cp "$BRIDGE/mex-build/matlab_ma57_setfunctions_bridge.cpp" "$MEX_BUILD/matlab_ma57_setfunctions_bridge.cpp"

cat > "$MEX_BUILD/compile_ipopt_mex_mumps59_matlab_ma57.m" <<EOF
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
  fullfile(mexBuild,'matlab_ma57_setfunctions_bridge.cpp')};

args = [{'-largeArrayDims', ['-I', mexBuild], '-Isrc', ...
  ['-I', fullfile(installRoot,'include','coin-or')], ...
  ['-I', fullfile(ipoptSrc,'src','Algorithm','LinearSolvers')], ...
  '-DOS_MAC', '-output', fullfile(mexBuild,'bin','ipopt')}, src, ...
  {'LDFLAGS=\$LDFLAGS -Wl,-ld_classic -Wl,-no_compact_unwind -Wl,-dead_strip -framework CoreFoundation -framework IOKit -ldl', ...
  'LINKLIBS=\$LINKLIBS -Wl,-force_load,$PATCHED_IPOPT_LIB -Wl,-filelist,$MUMPS_FILELIST $SPRAL_LIB $METIS_LIB $HWLOC_LIB $OPENBLAS_LIB $GOMP_LIB $STDCXX_LIB $GFORTRAN_LIB $QUADMATH_LIB $GCC_LIB $ATOMIC_LIB', ...
  'CXXFLAGS=\$CXXFLAGS -Wall -O2 -fno-c++-static-destructors'}];

mex(args{:});

fprintf('Built: %s\\n', fullfile(mexBuild,'bin',['ipopt.',mexext]));
EOF

echo "Compiling MATLAB MEX..."
"$MATLAB" -batch "run('$MEX_BUILD/compile_ipopt_mex_mumps59_matlab_ma57.m')"

echo
echo "Built experimental MEX:"
echo "  $MEX_BIN/ipopt.mexmaca64"
echo
echo "Dependency check:"
otool -L "$MEX_BIN/ipopt.mexmaca64"
echo
echo "Embedded MUMPS version strings:"
strings "$MEX_BIN/ipopt.mexmaca64" | grep -E 'MUMPS [0-9]|MUMPS_5' | head -n 10 || true
