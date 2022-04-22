function [dsav, xsav, itssav, rhosav] = ...
    sddtensor(A, kmax, alphamin, lmax, rhomin)

%SDDTENSOR  Semidiscrete Tensor Decomposition.
%   [D, X] = SDDTENSOR(A) produces discrete matrices stored in the cell
%   array X and a vector D that can be used to generate the 10-term tensor
%   SDD that approximates A. The X cell array is formatted as follows: the
%   first cell holds the component of each decomposed vectors from the first
%   dimension, the second cell goes with the second dimension, and so
%   on. The kth term of the SDD would be given by D(k) times the outer
%   product of X{1}(:,K) x X{2}(:,k) x ... x X{n}(:,k) where n is the order
%   of A. If A were a simple matrix, then X{1} and X{2} would be equivalent,
%   respectively, to the X and Y generated by the regular SDD routine.
%
%   [D, X, ITS] = SDDTENSOR(...) also returns the number of inner
%   iterations for each outer iteration.  
%
%   [D, X, ITS, RHO] = SDDTENSOR(...) also returns a vector RHO containing
%   the norm-squared of the residual after each outer iteration. 
%
%   [...] = SDDTENSOR(A, K) produces a K-term tensor SDD. The default is 10.
%
%   [...] = SDDTENSOR(A, K, TOL) stops the inner iterations after the
%   improvement is less than TOL. The default is 0.01.
%
%   [...] = SDDTENSOR(A, K, TOL, L) specifies that the maximum number of
%   inner iterations is L. The default is 10. 
%
%   [...] = SDDTENSOR(A, K, TOL, L, R) produces an SDD approximation that
%   either has K terms or such that norm(A - B, 'fro') < R where B is the
%   tensor SDD approximation. The default is zero.
%
%
%SDDPACK: Software for the Semidiscrete Decomposition.
%Copyright (c) 1999 Tamara G. Kolda and Dianne P. O'Leary. 

% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free 
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.  
%
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
% or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
% for more details.  
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, write to the Free Software Foundation, Inc., 59
% Temple Place - Suite 330, Boston, MA 02111-1307, USA.  

%%% Check Input Arguments

if ~exist('A') 
  error('Incorrect number of inputs.');
end

if ~exist('kmax')
  kmax = 10;
end

if ~exist('alphamin')
  alphamin = 0.01;
end

if ~exist('lmax')
  lmax = 10;
end

if ~exist('rhomin')
  rhomin = 0;
else
  rhomin = rhomin^2;
end

%%% Initialization

n = ndims(A);				% order of A
m = size(A);				% vector of dimensions of A

tmp = A .* A;				% compute residual norm squared
for j = 1 : n
  tmp = sum(tmp);
end
rho = tmp;
clear tmp;

iitssav = [];

%%% Outer Loop

for k = 1 : kmax
  
  %%% Initialize y for Inner Loop

  x = cell(n,1);
  for j = 1 : n
    x{j} = ones(m(j),1);
  end

  %%% Inner Loop

  for l = 1 : lmax

    for j = 1 : n
    
      s = product(A, x, j);
      [x{j}, xcnt(j), tmp] = sddtsolve(s, m(j));

    end
    
    %%% Check Progress
    
    Axsqr =  tmp * xcnt(n);
    beta = Axsqr / prod(xcnt);
    
    if (l > 1)
      alpha = (beta - betabar) / betabar;
      if (alpha <= alphamin)
	break
      end
    end

    betabar = beta;
  
  end % l-loop
  
  %%% Save
    
  d = sqrt(Axsqr) / prod(xcnt);
  A = A - d * expand(x);
  for j = 1 : n
    xsav{j}(:,k) = x{j};
  end
  dsav(k, 1) = d;
  rho = max([rho - beta, 0]);
  rhosav(k) = rho;
  itssav(k) = l;
  
  %%% Threshold Test

  if (rho < rhomin)
    break;
  end
  
end % k-loop

return

%----------------------------------------------------------------------%

function B = expand(x)

%EXPAND Expand a decomposed tensor to a full tensor.
%
%  B = EXPAND(X) returns B, a full tensor, that is the result of the outer
%  product of all the elements of X.
%
%For use with SDDTENSOR.
%Tamara G. Kolda, Oak Ridge National Laboratory, 1999.
%Dianne P. O'Leary, University of Maryland and ETH, 1999.

n = size(x, 1);
for j = 1 : n
  m(j) = size(x{j}, 1);
end

tmp = x{1};
for j = 2 : n
  tmp = tmp * x{j}';
  tmp = reshape(tmp, prod(m(1:j)), 1);
end

B = reshape(tmp, m);


%----------------------------------------------------------------------%

function s = product(A,x,idx)

%PRODUCT Product (contracted) of a tensor and decomposed tensor. 
%
%   S = PRODUCT(A,X) computes the inner product of a tesnor A with a
%   decomposed tensor X.  S is a scalar.
%
%   S = PRODUCT(A,X,I) computes the contracted inner product of a tensor A 
%   with a decomposed tensor X without its Ith component.
%
%For use with SDDTENSOR.
%Tamara G. Kolda, Oak Ridge National Laboratory, 1999.
%Dianne P. O'Leary, University of Maryland and ETH, 1999.

if exist('idx')
  
  str = 'tmp = squeeze(A(';
  for i = 1 : ndims(A)
    if i == idx
      str = [str 'i'];
    else
      str = [str ':'];
    end
    if i == ndims(A)
      str = [str '));'];
    else
      str = [str ','];
    end
  end

  jj = [1 : idx-1, idx+1 : ndims(A)];
  
  for i = 1 : size(A, idx)
    
    eval(str);
    if ndims(A) == 2
      n = 1;
      m = length(tmp);
    else
      n = ndims(tmp);
      m = size(tmp);
    end
    
    for j = n : -1 : 1
      tmp = reshape (tmp, prod(m(1 : j-1)), m(j));
      tmp = tmp * x{jj(j)};
    end
    
    s(i) = tmp;
    
  end
  
else
  
  tmp = A;
  n = ndims(tmp);
  m = size(tmp);

  for j = n : -1 : 1
    tmp = reshape (tmp, prod(m(1 : j-1)), m(j));
    tmp = tmp * x{j};
  end
  
  s = tmp;
  
end

%----------------------------------------------------------------------%

function [x, imax, fmax] = sddtsolve(s, m)

%SDDTSOLVE Solve SDD subproblem
%   [X] = SDDTSOLVE(S, M) computes max(X'S)/(X'X) where M is the size of S.
%
%   [X, I] = SDDTSOLVE(S, M) additionally returns number of nonzeros in X.
%
%   [X, I, F] = SDDTSOLVE(S, M) additionally returns value of function at
%   the optimum.  
%
%For use with SDDTENSOR.
%Tamara G. Kolda, Oak Ridge National Laboratory, 1999.
%Dianne P. O'Leary, University of Maryland and ETH, 1999.

for i = 1 : m
  if s(i) < 0
    x(i, 1) = -1;
    s(i) = -s(i);
  else
    x(i, 1) = 1;
  end
end

[sorts, indexsort] = sort(-s);
sorts = -sorts;

clear f
f(1) = sorts(1);
for i = 2 : m
  f(i) = sorts(i) + f(i - 1);
end

f = (f.^2) ./ [1:m];

imax = 1;
fmax = f(1);
for i = 2 : m
  if f(i) >= fmax
    imax = i;
    fmax = f(i);
  end
end

for i = (imax + 1) : m
  x(indexsort(i)) = 0;
end

return

