# GPOPS-II IPOPT MEX macOS Build

This directory contains the Apple Silicon macOS build materials and precompiled
`ipopt.mexmaca64` used for GPOPS-II testing.

The included MEX supports:

```matlab
options.ipopt.linear_solver = 'mumps';
options.ipopt.linear_solver = 'ma57';
```

It does not expose SPRAL.  Unsupported linear solver names return
`info.status = -999` with a clean error message.

## Precompiled MEX

```text
bin/maca64/ipopt.mexmaca64
```

SHA256:

```text
0c67a6c949fbf19cb12dd830c862b388844308da7c97fd30ad9d90c05b4d3b05
```

## Build Summary

The tested macOS build uses:

- IPOPT 3.14.19
- MUMPS 5.9.0
- MATLAB's installed MA57 runtime via an internal bridge
- MATLAB R2025b
- Apple Silicon `maca64`

The MEX does not link to Homebrew dynamic libraries at runtime.  The expected
runtime dependencies are system libraries and MATLAB's `libmx`/`libmex`.

The MA57 bridge dynamically loads:

```text
matlabroot/bin/maca64/libmwma57.dylib
```

No `options.ipopt.hsllib` setting is required for this MEX.

## Included Files

```text
bin/maca64/
  ipopt.mexmaca64
  SHA256SUMS.txt

scripts/
  build_ipopt_mumps59_matlab_ma57_bridge.sh
  build_full_ipopt_mumps59_matlab_ma57_bridge.sh
  compile_ipopt_mex_full_mumps59_matlab_ma57.m

src/
  IpoptInterfaceCommon.hh
  IpoptInterfaceCommon_safe.cc
  ipopt_setfunctions.cc
  matlab_ma57_setfunctions_bridge.cpp
  ma57_link_stubs.cpp

patches/
  Algorithm/
    IpBacktrackingLineSearch.cpp
    IpIpoptAlg.cpp
    IpRestoMinC_1Nrm.cpp
    LinearSolvers/IpSpralSolverInterface.cpp

tests/
  test_hs071_full_mumps59_ma57.m
  test_invalid_solver_guard.m
```

## Test

From MATLAB:

```matlab
addpath('/path/to/this/repository/macos/bin/maca64','-begin')
clear mex
rehash
which ipopt -all
run('/path/to/this/repository/macos/tests/test_hs071_full_mumps59_ma57.m')
run('/path/to/this/repository/macos/tests/test_invalid_solver_guard.m')
```

Expected HS071 result:

```text
HS071 mumps status=0 objective=17.0140171404
HS071 ma57  status=0 objective=17.0140171404
```

## Build Reproducibility Note

The build scripts record the tested local build recipe.  They may require
editing local paths for a different machine.  In particular, they expect local
source trees for IPOPT and prerequisite libraries and a MATLAB installation
capable of building `mexmaca64` files.

The first script prepares the MUMPS 5.9.0 pieces used by the final build.  The
second script rebuilds IPOPT and links the final MATLAB MEX.
