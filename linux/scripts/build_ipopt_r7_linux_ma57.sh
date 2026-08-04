#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

export IPOPT_R7_SANDBOX_ROOT="$ROOT"
export TMP_ROOT="${TMP_ROOT:-/tmp/ipopt-r7-linux-ma57-sandbox}"
export BUILD_DIR="${BUILD_DIR:-$TMP_ROOT/build-linux}"
export INSTALL_DIR="${INSTALL_DIR:-$TMP_ROOT/install-linux}"
export LOG_DIR="${LOG_DIR:-$TMP_ROOT/logs}"
export SRC_DIR="${SRC_DIR:?Set SRC_DIR to the directory containing the staged MEX sources}"
export IPOPT_SRC="${IPOPT_SRC:-}"
export MUMPS_SRC="${MUMPS_SRC:-$ROOT/third_party/src/MUMPS_5.9.1}"
export IPOPT_MEX_TOOLBOX="${IPOPT_MEX_TOOLBOX:?Set IPOPT_MEX_TOOLBOX to the mexIPOPT toolbox directory}"
export MATLAB_ROOT="${MATLAB_ROOT:-/usr/local/MATLAB/R2026a}"
export CC="${CC:-/usr/bin/x86_64-linux-gnu-gcc-12}"
export CXX="${CXX:-/usr/bin/g++-12}"
export FC="${FC:-/usr/bin/gfortran-12}"
export F77="${F77:-/usr/bin/gfortran-12}"
export JOBS="${JOBS:-4}"

MUMPS_ARCHIVE_SHA256_EXPECTED="659c9b57646b5a003ac618baa1faf9dd2044e46c732b3daaccbc7158003e1b46"

mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$LOG_DIR"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

need_file() {
  [ -f "$1" ] || fail "Missing required file: $1"
}

need_dir() {
  [ -d "$1" ] || fail "Missing required directory: $1"
}

for tool in bash sha256sum sed cp mkdir; do
  need_cmd "$tool"
done

for tool in "$CC" "$CXX" "$FC" /usr/bin/cmake /usr/bin/make /usr/bin/ninja; do
  [ -x "$tool" ] || fail "Missing required tool executable: $tool"
done

need_dir "$SRC_DIR"
need_dir "$IPOPT_MEX_TOOLBOX"
need_dir "$MATLAB_ROOT"
need_dir "$MUMPS_SRC"

if [ ! -f "$MATLAB_ROOT/bin/glnxa64/libmwma57.so" ] && [ ! -f "$MATLAB_ROOT/sys/os/glnxa64/libmwma57.so" ]; then
  fail "MATLAB MA57 runtime not found under $MATLAB_ROOT"
fi

[ -n "$IPOPT_SRC" ] || fail "Set IPOPT_SRC to an unpacked IPOPT 3.14.19 source tree."
need_dir "$IPOPT_SRC"

if [ -n "${MUMPS_ARCHIVE:-}" ]; then
  need_file "$MUMPS_ARCHIVE"
  actual_sha=$(sha256sum "$MUMPS_ARCHIVE" | sed 's/ .*//')
  [ "$actual_sha" = "$MUMPS_ARCHIVE_SHA256_EXPECTED" ] || fail \
    "MUMPS archive checksum mismatch: expected $MUMPS_ARCHIVE_SHA256_EXPECTED got $actual_sha"
fi

PATCH_DST="$BUILD_DIR/ipopt-src-patched"
rm -rf "$PATCH_DST"
cp -a "$IPOPT_SRC" "$PATCH_DST"
cp "$ROOT/patches/Algorithm/IpBacktrackingLineSearch.cpp" "$PATCH_DST/src/Algorithm/"
cp "$ROOT/patches/Algorithm/IpIpoptAlg.cpp" "$PATCH_DST/src/Algorithm/"
cp "$ROOT/patches/Algorithm/IpRestoMinC_1Nrm.cpp" "$PATCH_DST/src/Algorithm/"

export IPOPT_SRC="$PATCH_DST"

bash "$SCRIPT_DIR/build_openblas_linux.sh"
bash "$SCRIPT_DIR/build_gklib_linux.sh"
bash "$SCRIPT_DIR/build_metis_linux.sh"
bash "$SCRIPT_DIR/build_mumps_linux.sh"
bash "$SCRIPT_DIR/build_ipopt_loader_linux.sh"

cat <<EOF
Dependency build complete.

Next step inside MATLAB:
  setenv('IPOPT_R7_SANDBOX_ROOT','$ROOT');
  setenv('IPOPT_MEX_TOOLBOX','$IPOPT_MEX_TOOLBOX');
  run('$SCRIPT_DIR/compile_ipopt_mex_linux_ma57.m');
EOF
