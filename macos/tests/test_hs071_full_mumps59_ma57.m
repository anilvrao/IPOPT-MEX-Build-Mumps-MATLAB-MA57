function test_hs071_full_mumps59_ma57()
thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'bin', 'maca64'), '-begin');
clear mex;
rehash;

solvers = {'mumps','ma57'};
for k = 1:numel(solvers)
  solver = solvers{k};
  funcs.objective         = @objective;
  funcs.gradient          = @gradient;
  funcs.constraints       = @constraints;
  funcs.jacobian          = @jacobian;
  funcs.jacobianstructure = @jacobianstructure;
  funcs.hessian           = @hessian;
  funcs.hessianstructure  = @hessianstructure;

  options.lb = [1; 1; 1; 1];
  options.ub = [5; 5; 5; 5];
  options.cl = [25; 40];
  options.cu = [Inf; 40];
  options.ipopt.print_level = 0;
  options.ipopt.linear_solver = solver;
  options.ipopt.tol = 1e-9;
  if strcmp(solver,'ma57')
    options.ipopt.ma57_pivot_order = 2;
    options.ipopt.ma57_automatic_scaling = 'yes';
  end

  [x, info] = ipopt([1; 5; 5; 1], funcs, options);
  fprintf('HS071 %-5s status=%d objective=%.12g x=[%.8g %.8g %.8g %.8g]\n', ...
    solver, info.status, objective(x), x(1), x(2), x(3), x(4));
end

function f = objective(x)
f = x(1)*x(4)*(x(1)+x(2)+x(3)) + x(3);

function g = gradient(x)
g = [x(4)*(2*x(1)+x(2)+x(3)); x(1)*x(4); x(1)*x(4)+1; x(1)*(x(1)+x(2)+x(3))];

function c = constraints(x)
c = [prod(x); sum(x.^2)];

function J = jacobian(x)
J = sparse([x(2)*x(3)*x(4), x(1)*x(3)*x(4), x(1)*x(2)*x(4), x(1)*x(2)*x(3); ...
            2*x(1), 2*x(2), 2*x(3), 2*x(4)]);

function J = jacobianstructure()
J = sparse(ones(2,4));

function H = hessian(x, sigma, lambda)
H = sigma*[2*x(4), 0, 0, 2*x(1)+x(2)+x(3); ...
           0, 0, 0, x(1); ...
           0, 0, 0, x(1); ...
           2*x(1)+x(2)+x(3), x(1), x(1), 0];
H = H + lambda(1)*[0, x(3)*x(4), x(2)*x(4), x(2)*x(3); ...
                   x(3)*x(4), 0, x(1)*x(4), x(1)*x(3); ...
                   x(2)*x(4), x(1)*x(4), 0, x(1)*x(2); ...
                   x(2)*x(3), x(1)*x(3), x(1)*x(2), 0];
H = H + lambda(2)*2*eye(4);
H = sparse(tril(H));

function H = hessianstructure()
H = sparse(tril(ones(4,4)));
