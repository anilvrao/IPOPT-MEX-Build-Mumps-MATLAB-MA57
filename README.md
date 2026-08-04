# MATLAB IPOPT MEX Builds

This repository contains build materials and precompiled MATLAB IPOPT MEX files for Apple Silicon macOS, 64-bit Windows, and x86-64 Linux.

Both builds provide exactly these linear solvers:

```matlab
options.ipopt.linear_solver = 'mumps';
options.ipopt.linear_solver = 'ma57';
```

Unsupported solver names are rejected before optimization starts and return `info.status = -999`. SPRAL is not built or linked.

## 2026-08-02 release candidate

| Platform | Binary | SHA-256 |
|---|---|---|
| Apple Silicon macOS | `macos/bin/maca64/ipopt.mexmaca64` | `64808ff656291c947c2c7a171211d9913d8d668c62e1415b106b92aa907a5054` |
| 64-bit Windows | `windows/bin/win64/ipopt.mexw64` | `adbf4bc9bf8d9d67c89cbfb3b7cd8cdd000c9dba4d08bff07975e406beda8835` |
| x86-64 Linux | `linux/bin/mexa64/ipopt.mexa64` | `d29971b6b092764708594e207cafe27057ed06e32e140428f84732afc99e1e3c` |

The two builds use:

- IPOPT 3.14.19
- official MUMPS 5.9.1 source (SHA-256 `659c9b57646b5a003ac618baa1faf9dd2044e46c732b3daaccbc7158003e1b46`)
- MATLAB's installed MA57 library through an internal bridge
- statically linked IPOPT and MUMPS code
- fault-containment patches for restoration and line-search failure paths
- no SPRAL

MA57 is not redistributed. The bridge loads the library supplied by the active MATLAB installation (`libmwma57.dylib` on macOS, `libmwma57.dll` on Windows, or `libmwma57.so` on Linux).

## Validation

The macOS binary has been exercised with GPOPS-II examples using MUMPS and MA57 in MATLAB R2024b, R2025a, R2025b, and R2026a on Apple Silicon without the previous MATLAB crashes. The Windows binary passed the MUMPS, MA57, and invalid-solver HS071 tests in R2024a and R2026a; it was also exercised with GPOPS-II examples in R2024b and R2026a.

Ctrl-C during a native IPOPT solve is not claimed as a supported interruption mechanism. GPOPS-II can still be stopped between mesh-refinement iterations.

## Layout

```text
macos/                       Apple Silicon binary, sources, patches, scripts, tests
windows/                     Windows binary, sources, patches, scripts, tests
windows/BUILD_MANIFEST.txt   Exact Windows build and validation record
linux/                       x86-64 Linux binary, sources, patches, and scripts
```

See [macos/README.md](macos/README.md), [windows/README.md](windows/README.md), and [linux/README.md](linux/README.md) for platform-specific instructions.

## macOS smoke test

```matlab
addpath('/path/to/repository/macos/bin/maca64','-begin')
clear mex
rehash
which ipopt -all
run('/path/to/repository/macos/tests/test_hs071_full_mumps59_ma57.m')
run('/path/to/repository/macos/tests/test_invalid_solver_guard.m')
```

## Third-party code

Large third-party source trees are intentionally excluded. Obtain IPOPT, MUMPS, compiler tools, and MATLAB separately. MATLAB's MA57 runtime is supplied by the user's MATLAB installation and is not included as a separate library.
