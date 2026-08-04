function test_invalid_solver_guard()
thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'bin', 'maca64'), '-begin');
clear mex;
rehash;

funcs.objective         = @(x) x(1)^2;
funcs.gradient          = @(x) 2*x(1);
funcs.constraints       = @(x) sparse([]);
funcs.jacobian          = @(x) sparse(0,1);
funcs.jacobianstructure = @() sparse(0,1);

options.lb = -10;
options.ub = 10;
options.cl = [];
options.cu = [];
options.ipopt.print_level = 0;
options.ipopt.linear_solver = 'spral';

[~, info] = ipopt(1, funcs, options);
fprintf('invalid solver status=%d\n', info.status);
assert(info.status == -999, 'Nested invalid linear solver was not rejected.');
if isfield(info, 'message')
  fprintf('%s\n', info.message);
end

flatOptions = options;
flatOptions.linear_solver = flatOptions.ipopt.linear_solver;
flatOptions = rmfield(flatOptions, 'ipopt');
[~, flatInfo] = ipopt(1, funcs, flatOptions);
fprintf('flat invalid solver status=%d\n', flatInfo.status);
assert(flatInfo.status == -999, 'Flat invalid linear solver was not rejected.');
