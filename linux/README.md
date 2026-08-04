# x86-64 Linux IPOPT MEX

This directory contains the x86-64 Linux IPOPT MEX shipped with GPOPS-II R7 and the Linux build materials prepared for IPOPT 3.14.19, MUMPS 5.9.1, and MATLAB's installed MA57 runtime. SPRAL is not included.

The checked-in binary is the exact R7 artifact. The included scripts and sources record the Linux build work, but a byte-for-byte reproducible rebuild is not claimed.

## Binary verification

```sh
cd linux/bin/mexa64
sha256sum -c SHA256SUMS.txt
```

Expected SHA-256: `d29971b6b092764708594e207cafe27057ed06e32e140428f84732afc99e1e3c`.

## Build outline

Install MATLAB and GCC/G++/gfortran, then provide absolute source paths through environment variables:

```sh
export IPOPT_SRC=/absolute/path/to/Ipopt-3.14.19
export MUMPS_SRC=/absolute/path/to/MUMPS_5.9.1
export IPOPT_MEX_TOOLBOX=/absolute/path/to/mexIPOPT/toolbox
export TMP_ROOT=/tmp/ipopt-r7-linux-ma57
bash linux/scripts/build_ipopt_r7_linux_ma57.sh
```

Run `linux/scripts/compile_ipopt_mex_linux_ma57.m` from MATLAB for the final MEX link. The MATLAB installation must contain `bin/glnxa64/libmwma57.so` for MA57 use.
