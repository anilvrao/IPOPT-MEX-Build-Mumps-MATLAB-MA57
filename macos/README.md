# MATLAB IPOPT MEX macOS Build

This directory contains the Apple Silicon `ipopt.mexmaca64`, its MEX-interface sources, IPOPT fault-containment patches, build scripts, and smoke tests.

## Precompiled binary

```text
bin/maca64/ipopt.mexmaca64
SHA-256: 3b097ad0af33e4daf193325934fa41b1b83fc6325e5df60f103b4840b4476f3a
```

The build uses IPOPT 3.14.19, MUMPS 5.9.1, and MATLAB's installed MA57 runtime. It supports `mumps` and `ma57`; unsupported solver names return `info.status = -999`. SPRAL is neither built nor linked.

The MA57 bridge loads `matlabroot/bin/maca64/libmwma57.dylib`. No `options.ipopt.hsllib` setting is required. Runtime dependencies are limited to MATLAB and macOS system libraries; there are no Homebrew dynamic-library dependencies.

## Important build properties

- Apple `libc++` is the only C++ exception runtime.
- Normal compact-unwind information is retained. Do not add `-Wl,-no_compact_unwind`; that caused restoration exceptions to terminate MATLAB instead of reaching IPOPT's handlers.
- MA57E pointers are forwarded directly because both sides use the same 64-bit integer ABI. This avoids the former speculative workspace copy during factor expansion.
- MUMPS and GNU Fortran support libraries are linked statically.
- METIS, hwloc, GNU OpenMP, GNU `libstdc++`, and SPRAL are absent.

## Test

```matlab
addpath('/path/to/repository/macos/bin/maca64','-begin')
clear mex
rehash
which ipopt -all
run('/path/to/repository/macos/tests/test_hs071_full_mumps59_ma57.m')
run('/path/to/repository/macos/tests/test_invalid_solver_guard.m')
```

Expected results are status 0 for HS071 with MUMPS and MA57, and status -999 for unsupported solvers in both nested and flat option layouts. The binary was exercised with optimization test problems in MATLAB R2024b, R2025a, R2025b, and R2026a without the previous MATLAB crashes. The MUMPS 5.9.1 rebuild also passed multiple mesh-refinement iterations and difficult launch regressions with MUMPS and MA57.

## Rebuilding

`scripts/build_full_ipopt_mumps59_matlab_ma57_bridge.sh` records the validated link recipe. Set `IPOPT_MEX_WORK_ROOT` and, as necessary, its path overrides for local IPOPT, MUMPS, OpenBLAS, compiler, and MATLAB installations. The script takes the interface sources and three IPOPT patches directly from this `macos` directory.
