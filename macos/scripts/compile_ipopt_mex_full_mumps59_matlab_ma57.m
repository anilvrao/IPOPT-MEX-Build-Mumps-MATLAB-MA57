function compile_ipopt_mex_full_mumps59_matlab_ma57()
% Compile the GPOPS-II IPOPT MEX wrapper against prebuilt static libraries.
%
% This is a portable template.  The full shell build writes a concrete compile
% driver with exact paths after building IPOPT and MUMPS.  To use this template
% directly, define the environment variables below before launching MATLAB.

scriptDir = fileparts(mfilename('fullpath'));
macosDir = fullfile(scriptDir, '..');
srcDir = fullfile(macosDir, 'src');
outDir = fullfile(macosDir, 'bin', 'maca64');

toolbox = requiredEnv('MEXIPOPT_ROOT');
installRoot = requiredEnv('IPOPT_INSTALL_ROOT');
ipoptSrc = requiredEnv('IPOPT_SRC_ROOT');
ipoptFlatLib = requiredEnv('IPOPT_FLAT_LIB');
mumpsFilelist = requiredEnv('MUMPS_OBJECTS_FILELIST');
spralLib = getenv('SPRAL_LIB');
metisLib = requiredEnv('METIS_LIB');
hwlocLib = getenv('HWLOC_LIB');
openblasLib = requiredEnv('OPENBLAS_LIB');
gompLib = getenv('GOMP_LIB');
stdcxxLib = getenv('GCC_STDCXX_LIB');
gfortranLib = requiredEnv('GFORTRAN_LIB');
quadmathLib = requiredEnv('QUADMATH_LIB');
gccLib = requiredEnv('GCC_LIB');
atomicLib = getenv('GCC_ATOMIC_LIB');

oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(toolbox);

src = {fullfile(srcDir, 'ipopt_setfunctions.cc'), ...
  fullfile(srcDir, 'IpoptInterfaceCommon_safe.cc'), ...
  fullfile(srcDir, 'matlab_ma57_setfunctions_bridge.cpp'), ...
  fullfile(srcDir, 'ma57_link_stubs.cpp')};

linkLibs = strjoin(nonempty({ ...
  ['-Wl,-force_load,' ipoptFlatLib], ...
  ['-Wl,-filelist,' mumpsFilelist], ...
  spralLib, metisLib, hwlocLib, openblasLib, gompLib, stdcxxLib, ...
  gfortranLib, quadmathLib, gccLib, atomicLib}), ' ');

args = [{'-largeArrayDims', ['-I', srcDir], '-Isrc', ...
  ['-I', fullfile(installRoot, 'include', 'coin-or')], ...
  ['-I', fullfile(ipoptSrc, 'src', 'Algorithm', 'LinearSolvers')], ...
  '-DOS_MAC', '-output', fullfile(outDir, 'ipopt')}, src, ...
  {'LDFLAGS=$LDFLAGS -Wl,-ld_classic -Wl,-no_compact_unwind -Wl,-dead_strip -framework CoreFoundation -framework IOKit -ldl', ...
  ['LINKLIBS=$LINKLIBS ' linkLibs], ...
  'CXXFLAGS=$CXXFLAGS -Wall -O2 -DFUNNY_MA57_FINT -fno-c++-static-destructors'}];

mex(args{:});
fprintf('Built: %s\n', fullfile(outDir, ['ipopt.' mexext]));

function value = requiredEnv(name)
value = getenv(name);
if isempty(value)
  error('compileIpoptMex:MissingEnvironment', ...
    'Environment variable %s must be set.', name);
end

function values = nonempty(values)
values = values(~cellfun('isempty', values));
