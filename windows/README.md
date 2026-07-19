# MATLAB IPOPT MEX Windows Build

This directory contains the build scripts and small MATLAB MEX interface sources
used to build a Windows `ipopt.mexw64` for MATLAB with:

- IPOPT statically linked into the MEX
- MUMPS statically linked into the MEX
- Intel MKL sequential statically linked into the MEX
- No SPRAL
- Internal MATLAB MA57 bridge source compiled into the MEX
- MATLAB's `libmwma57.dll` loaded at runtime by the bridge
- A clean invalid-linear-solver guard for unsupported solvers

The intended supported IPOPT linear solvers are:

```matlab
options.ipopt.linear_solver = 'mumps';
options.ipopt.linear_solver = 'ma57';
```

The build is intended for MATLAB on Windows using Microsoft Visual Studio and
Intel oneAPI.

## What Is Included

```text
src/
  IpoptInterfaceCommon.hh
  IpoptInterfaceCommon_safe.cc
  ipopt_setfunctions.cc
  matlab_ma57_setfunctions_bridge.cpp
  ma28_dependency_detector_unavailable.cpp
  hsl_link_stubs.cpp
  CoinHslConfig.h

scripts/
  configure_ipopt_static_msvc_ifx_mumps_ma57.sh
  configure_ipopt_static_msvc_ifx_mumps_ma57.bat
  build_ipopt_static_msvc_ifx_mumps_ma57.bat
  build_mex_solver_static.m
  test_hs071.m

bin/win64/
  ipopt.mexw64
  SHA256SUMS.txt
```

## What Is Not Included

This folder intentionally does not include large third-party source trees.
Obtain those separately:

- IPOPT source, tested with Ipopt 3.14.19
- MUMPS source, built into static libraries
- Intel oneAPI compiler and MKL
- Microsoft Visual Studio Build Tools
- MATLAB
- MSYS2 for running the IPOPT autotools configure/make steps

The MEX interface source files in `src/` are the IPOPT MEX interface
sources, not the OPTI Toolbox MATLAB wrapper.

## Environment Variables

Set these before building:

```bat
set IPOPT_SRC=C:\path\to\Ipopt-releases-3.14.19
set MUMPS_ROOT=C:\path\to\MUMPS
set MATLAB_ROOT=C:\Program Files\MATLAB\R2024a
```

Optional overrides:

```bat
set MKL_ROOT=C:\Program Files (x86)\Intel\oneAPI\mkl\latest
set INTEL_COMPILER_ROOT=C:\Program Files (x86)\Intel\oneAPI\compiler\latest
set VSDEV_CMD=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat
set ONEAPI_SETVARS=C:\Program Files (x86)\Intel\oneAPI\setvars.bat
set MSYS2_BASH=C:\msys64\usr\bin\bash.exe
```

`MUMPS_ROOT` should contain:

```text
MUMPS_ROOT\include
MUMPS_ROOT\libseq
MUMPS_ROOT\lib\libdmumps.lib
MUMPS_ROOT\lib\libmumps_common.lib
MUMPS_ROOT\lib\libpord.lib
MUMPS_ROOT\lib\libmpiseq.lib
```

## Build

From a normal Windows command prompt:

```bat
scripts\configure_ipopt_static_msvc_ifx_mumps_ma57.bat
scripts\build_ipopt_static_msvc_ifx_mumps_ma57.bat
"%MATLAB_ROOT%\bin\matlab.exe" -batch "run('scripts/build_mex_solver_static.m')"
```

The MEX will be written to:

```text
mex\win64_msvc_ifx_mumps_ma57_solver_static\ipopt.mexw64
```

## Prebuilt Windows MEX

This repository includes a prebuilt Windows MEX:

```text
bin\win64\ipopt.mexw64
```

It supports:

```matlab
options.ipopt.linear_solver = 'mumps';
options.ipopt.linear_solver = 'ma57';
```

It does not include SPRAL. If an unsupported solver is requested, the MEX should
return `info.status = -999` with a clean error message rather than crashing
MATLAB.

The known checksum for the included Windows MEX is:

```text
1E4E13B4A3F30742F31BAECC4F15F785614E129CD784966D8801C5F1A73DD83D
```

## Test

```bat
"%MATLAB_ROOT%\bin\matlab.exe" -batch "run('scripts/test_hs071.m')"
```

Expected behavior:

- `linear_solver = 'spral'` returns `info.status = -999`
- `linear_solver = 'mumps'` solves HS071
- `linear_solver = 'ma57'` solves HS071

## Dependency Check

Use Visual Studio `dumpbin`:

```bat
dumpbin /dependents mex\win64_msvc_ifx_mumps_ma57_solver_static\ipopt.mexw64
```

The target build has no external IPOPT, MUMPS, MKL, Intel Fortran, or Intel math
DLL dependencies. It should depend only on MATLAB DLLs and normal Windows/MSVC
runtime DLLs.

## Known Final Test Build

The final development-machine test MEX had SHA256:

```text
1E4E13B4A3F30742F31BAECC4F15F785614E129CD784966D8801C5F1A73DD83D
```

It passed HS071 smoke tests in MATLAB R2024a and MATLAB R2026a.
