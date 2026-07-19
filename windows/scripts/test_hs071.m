clear functions;
clear mex;

scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
mexDir = fullfile(root, 'mex', 'win64_msvc_ifx_mumps_ma57_solver_static');
overrideMexDir = getenv('IPOPT_MEX_TEST_DIR');
if ~isempty(overrideMexDir)
  mexDir = overrideMexDir;
end

setenv('OMP_CANCELLATION', 'TRUE');
addpath(mexDir, '-begin');

fprintf('MATLAB: %s\n', version);
fprintf('MEX path: %s\n', which('ipopt'));

testInvalidSolver();
runOne('mumps');
runOne('ma57');

function testInvalidSolver()
fprintf('\n===== HS071 with invalid solver spral =====\n');
[x0, funcs, options] = hs071Problem();
options.ipopt.linear_solver = 'spral';
[x, info] = ipopt(x0, funcs, options);
disp(x);
disp(info);
if ~isfield(info, 'status') || info.status ~= -999
  error('Invalid solver did not return status -999.');
end
if ~isfield(info, 'message') || ~contains(info.message, 'linear_solver')
  error('Invalid solver did not return the expected short message.');
end
end

function runOne(linearSolver)
fprintf('\n===== HS071 with %s =====\n', linearSolver);
[x0, funcs, options] = hs071Problem();
options.ipopt.linear_solver = linearSolver;
if strcmpi(linearSolver, 'ma57')
  options.ipopt.ma57_pivot_order = 2;
  options.ipopt.ma57_automatic_scaling = 'yes';
end
[x, info] = ipopt(x0, funcs, options);
disp(x);
disp(info);
if ~isfield(info, 'status') || info.status ~= 0
  error('HS071 failed with %s. IPOPT status was %s.', linearSolver, mat2str(info.status));
end
end

function [x0, funcs, options] = hs071Problem()
funcs.objective         = @(x) x(1)*x(4)*sum(x(1:3)) + x(3);
funcs.gradient          = @hs071Gradient;
funcs.constraints       = @(x) [prod(x); sum(x.^2)];
funcs.jacobian          = @(x) sparse([prod(x)./x; 2*x]);
funcs.jacobianstructure = @() sparse(ones(2,4));
funcs.hessian           = @hs071Hessian;
funcs.hessianstructure  = @() sparse(tril(ones(4)));

options.lb = [1 1 1 1];
options.ub = [5 5 5 5];
options.cl = [25 40];
options.cu = [Inf 40];
options.ipopt.print_level = 0;
options.ipopt.tol = 1e-8;
options.ipopt.max_iter = 100;

x0 = [1 5 5 1];
end

function g = hs071Gradient(x)
g = [x(4)*(2*x(1)+x(2)+x(3)); ...
     x(1)*x(4); ...
     x(1)*x(4)+1; ...
     x(1)*(x(1)+x(2)+x(3))];
end

function H = hs071Hessian(x, sigma, lambda)
H = sigma * [ ...
  2*x(4), 0, 0, 2*x(1)+x(2)+x(3); ...
  0, 0, 0, x(1); ...
  0, 0, 0, x(1); ...
  2*x(1)+x(2)+x(3), x(1), x(1), 0];

H = H + lambda(1) * [ ...
  0, x(3)*x(4), x(2)*x(4), x(2)*x(3); ...
  x(3)*x(4), 0, x(1)*x(4), x(1)*x(3); ...
  x(2)*x(4), x(1)*x(4), 0, x(1)*x(2); ...
  x(2)*x(3), x(1)*x(3), x(1)*x(2), 0];

H = H + 2*lambda(2)*eye(4);
H = sparse(tril(H));
end
