# MATLAB IPOPT MEX Windows Build

This directory contains the 64-bit Windows `ipopt.mexw64`, its MEX-interface sources, IPOPT fault-containment patches, build scripts, and dependency pins.

## Precompiled binary

```text
bin/win64/ipopt.mexw64
SHA-256: adbf4bc9bf8d9d67c89cbfb3b7cd8cdd000c9dba4d08bff07975e406beda8835
```

The build uses IPOPT 3.14.19, MUMPS 5.9.1, Microsoft Visual C++ 2022, Intel oneAPI ifx/icx 2025.3.2, and MATLAB R2024a's MEX compiler. IPOPT and MUMPS are linked into the MEX. MATLAB's installed `libmwma57.dll` is loaded at runtime by the internal MA57 bridge.

Supported linear solvers are `mumps` and `ma57`. Unsupported names are rejected before IPOPT starts and return `info.status = -999`. SPRAL is not built or linked. The binary may contain IPOPT's generic SPRAL option-description text; that text is not a library dependency.

## Build inputs

The final build used:

- IPOPT 3.14.19 with the three files under `patches/Algorithm/` applied
- official MUMPS 5.9.1, pinned in `third_party/COMPONENTS.sha256`
- `third_party/MUMPS_5.9.1.Makefile.inc.msvc-ifx`
- Microsoft Visual Studio 2022, Intel oneAPI, MATLAB, and MSYS2

Set `IPOPT_SRC`, `MUMPS_ROOT`, and `MATLAB_ROOT` before running the scripts. The exact successful build record is preserved in `BUILD_MANIFEST.txt`.

## Test

```bat
"%MATLAB_ROOT%\bin\matlab.exe" -batch "run('scripts/test_hs071.m')"
```

Expected behavior:

- invalid `linear_solver='spral'`: status -999
- `linear_solver='mumps'`: HS071 status 0
- `linear_solver='ma57'`: HS071 status 0

These tests passed in MATLAB R2024a and R2026a. Optimization test problems using MUMPS and MA57 were also exercised in R2024b and R2026a without MATLAB crashes.

## Runtime dependency check

`dumpbin /dependents` reports only MATLAB, MSVC/UCRT, KERNEL32, and imagehlp DLLs. There are no external IPOPT, MUMPS, SPRAL, GNU, MSYS, MinGW, Intel Fortran, or Intel math runtime DLL dependencies. See `BUILD_MANIFEST.txt` for the recorded list.
