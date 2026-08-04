#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_linux_common.sh"

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MUMPS_SRC="${MUMPS_SRC:-$ROOT/third_party/src/MUMPS_5.9.1}"
BLD="$BUILD_DIR/mumps"
STAGE="$BUILD_DIR/mumps-src"
LOG="$LOG_DIR/build_mumps.log"

rm -rf "$BLD"
rm -rf "$STAGE"
mkdir -p "$BLD" "$STAGE" "$MUMPS/lib" "$MUMPS/include/coin-or/mumps"
exec > >(tee "$LOG") 2>&1

echo "MUMPS build started: $(date)"
echo "Official MUMPS source: $MUMPS_SRC"

[ -d "$MUMPS_SRC" ] || { echo "Missing MUMPS source tree: $MUMPS_SRC" >&2; exit 1; }

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$MUMPS_SRC/" "$STAGE/"
else
  cp -a "$MUMPS_SRC/." "$STAGE/"
fi

cat > "$STAGE/Makefile.inc" <<EOF
PLAT    =
LIBEXT_SHARED  = .so
SONAME = -soname
SHARED_OPT = -shared
FPIC_OPT = -fPIC
LIBEXT  = .a
OUTC    = -o
OUTF    = -o
RM      = /bin/rm -f
CC      = $CC
FC      = $FC
FL      = $FC
AR      = $AR rv
RANLIB  = $RANLIB

LPORDDIR = \$(topdir)/PORD/lib/
IPORD    = -I\$(topdir)/PORD/include/
LPORD    = -L\$(LPORDDIR) -lpord\$(PLAT)

LMETISDIR = $METIS/lib
IMETIS    = -I$METIS/include -I$GKLIB/include
LMETIS    = $METIS_LIBFILE $GKLIB_LIBFILE

ORDERINGSF = -Dmetis -Dpord
ORDERINGSC = \$(ORDERINGSF)

LORDERINGS = \$(LMETIS) \$(LPORD)
IORDERINGSF =
IORDERINGSC = \$(IMETIS) \$(IPORD)

LAPACK = $OPENBLAS_LIBFILE
INCSEQ = -I\$(topdir)/libseq
LIBSEQ = \$(LAPACK) -L\$(topdir)/libseq -lmpiseq\$(PLAT)
LIBBLAS = $OPENBLAS_LIBFILE
LIBOTHERS = -lpthread

CDEFS = -DAdd_

OPTF = -O2 -fPIC -fallow-argument-mismatch
OPTC = -O2 -fPIC -I. -I$METIS/include -I$GKLIB/include
OPTL = -O2 -fPIC

INCS = \$(INCSEQ)
LIBS = \$(LIBSEQ)
LIBSEQNEEDED = libseqneeded
EOF

cd "$STAGE"
make clean || true
make d -j"$JOBS"

cp -f lib/libdmumps.a "$MUMPS/lib/"
cp -f lib/libmumps_common.a "$MUMPS/lib/"
cp -f lib/libpord.a "$MUMPS/lib/"
cp -f lib/libmpiseq.a "$MUMPS/lib/"
cp -f include/*.h "$MUMPS/include/coin-or/mumps/"
cp -f libseq/mpif.h "$MUMPS/include/coin-or/mumps/" || true
cp -f libseq/mpi.h "$MUMPS/include/coin-or/mumps/" || true

REPACK="$BLD/repack"
rm -rf "$REPACK"
mkdir -p "$REPACK"
cd "$REPACK"
for archive in \
  "$STAGE/lib/libdmumps.a" \
  "$STAGE/lib/libmumps_common.a" \
  "$STAGE/lib/libpord.a" \
  "$STAGE/lib/libmpiseq.a"; do
  "$AR" x "$archive"
done
"$AR" rcs "$MUMPS/lib/libcoinmumps.a" ./*.o
"$RANLIB" "$MUMPS/lib/libcoinmumps.a"

echo "MUMPS build finished: $(date)"
find "$MUMPS" -maxdepth 4 -type f -printf "%p %s\n" | sort
