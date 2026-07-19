# Third-Party Source Locations

This repository does not vendor third-party numerical package source trees.

For a reproducible build, obtain and record the versions used for:

- IPOPT, tested here with Ipopt 3.14.19
- MUMPS
- Intel oneAPI compiler and MKL
- Microsoft Visual Studio Build Tools
- MATLAB
- MSYS2

The scripts expect IPOPT and MUMPS to be supplied through the `IPOPT_SRC` and
`MUMPS_ROOT` environment variables.
