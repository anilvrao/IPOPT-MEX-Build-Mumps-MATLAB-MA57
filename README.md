# GPOPS-II IPOPT MEX Builds

This repository contains build materials and precompiled MATLAB IPOPT MEX files
prepared for use with GPOPS-II.

The included MEX files support the IPOPT linear solvers:

```matlab
options.ipopt.linear_solver = 'mumps';
options.ipopt.linear_solver = 'ma57';
```

Unsupported linear solver names are rejected before the optimization starts and
return a clean GPOPS-II/IPOPT error message instead of allowing IPOPT to proceed
with an unavailable linear solver.

## Precompiled MEX Files

```text
macos/bin/maca64/ipopt.mexmaca64
windows/bin/win64/ipopt.mexw64
```

Known checksums:

```text
0c67a6c949fbf19cb12dd830c862b388844308da7c97fd30ad9d90c05b4d3b05  macos/bin/maca64/ipopt.mexmaca64
95ea5bc05dd0b14844407050b3b5e0496fe5c45ec391fb08fbe03a52d4847984  windows/bin/win64/ipopt.mexw64
```

## Directory Layout

```text
macos/
  README.md
  bin/maca64/ipopt.mexmaca64
  scripts/
  src/
  patches/
  tests/

windows/
  README.md
  bin/win64/ipopt.mexw64
  scripts/
  src/
  third_party/
```

## macOS Build Summary

The macOS Apple Silicon MEX was built with:

- IPOPT 3.14.19
- MUMPS 5.9.0
- an internal MATLAB MA57 bridge
- MATLAB R2025b
- Apple Silicon target `maca64`

The MEX does not redistribute the MATLAB MA57 runtime as a separate library.  At
runtime, the internal bridge loads MATLAB's installed MA57 runtime from:

```text
matlabroot/bin/maca64/libmwma57.dylib
```

The macOS MEX has no Homebrew runtime library dependencies.

## Windows Build Summary

The Windows MEX was built with:

- IPOPT 3.14.19
- MUMPS
- an internal MATLAB MA57 bridge
- Microsoft Visual Studio / Intel oneAPI build tools
- MATLAB on Windows target `win64`

See [windows/README.md](windows/README.md) for the Windows-specific build notes.

## MATLAB Smoke Test

To test the macOS MEX from MATLAB:

```matlab
addpath('/path/to/this/repository/macos/bin/maca64','-begin')
clear mex
rehash
which ipopt -all
run('/path/to/this/repository/macos/tests/test_hs071_full_mumps59_ma57.m')
run('/path/to/this/repository/macos/tests/test_invalid_solver_guard.m')
```

To test the Windows MEX, see [windows/README.md](windows/README.md).

## Notes on Third-Party Code

This repository contains build glue, patches, small MEX-interface sources, and
precompiled MATLAB MEX files.  Large third-party source trees are intentionally
not included.  Obtain IPOPT, MUMPS, compiler tools, and MATLAB separately.

The MATLAB MA57 runtime is provided by the user's MATLAB installation and is not
included here as a separate redistributable HSL library.

