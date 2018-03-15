-- PUMICE Copyright (C) 2009 Lars Rosengreen (-*-coding:iso-safe-unix-*-)
-- released as free software under the terms of MIT open source license

-- A sparse matrix data structure.  Elements in the matrix that are
-- zero take up no memory.

-- to create a matrix do something like:
-- A = matrix{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}
--   -or more concisely-
-- B = matrix[[1 2 3; 4 5 6; 7 8 9]]

-- to perform basic matrix operations do something like:
-- C = A - B <-- addition
-- D = 2 * A <-- scalar multiplication
-- E = A * B <-- matrix multiplication

-- Internal structure of a matrix
--
-- M = { rows,        <-- number of rows in the matrix
--       columns,     <-- number of columns in the matrix
--       type,        <-- always "matrix"; used for comparisons with
--                        other data structures            
--       vectors = { [1] = vector, <-- each row in the matrix is stored 
--                   [2] = vector,     as a sparserow vector internally;
--                                     the total number of vectors is
--                   ...               rows, and the size of each row
--                                     vector is columns
-- 
--                   [rows] = vector } }


local vector = require "libs.vector"
local rational = require "libs.rational"
local inspect = require "inspect"
local matrix = {}
local matrixMt = {}
local weakMt = {__mode = "kv"}
local prototype = {type = "matrix"}

-- **RIVERS** addition for factorio

function matrix:Init()
    global.matrices = setmetatable({}, weakMt)
    global.matrixCount = 0
end

function matrix:Load()
    for _, matrix in pairs(global.matrices) do
        setmetatable(matrix, matrixMt)
    end
    setmetatable(global.matrices, weakMt)
end
----
---- constructors
----

-- Create a new matrix object of the given size.  All entries in the
-- returned matrix are 0.
function matrix.new(rows, columns)
   local columns = columns or rows
   local M = {}
   local vectors = {}
   for k, v in pairs(prototype) do
      M[k] = v
   end
   M.rows, M.columns = rows, columns
   if type(rows) ~= 'number' then error('????',2) end
   for i = 1, rows do
      vectors[i] = vector.new(columns)
   end
   M.vectors = vectors
   setmetatable(M, matrixMt)
   global.matrices[global.matrixCount] = M
   global.matrixCount = global.matrixCount + 1
   return M
end


-- Create a matrix from a nested table (column major form).
local function matrixFromTable(t, r, c)
    local m = matrix.new(r,c)
    for j, column in pairs(t) do
        for i, val in pairs(column) do
            if type(m[j]) ~= 'table' then 
                log(inspect(column))
                error("invalid vector type at: "..i..','..j..','..r..','..c,2) 
            end
            m[j][i] = val
        end
    end
    return m
end

local function __call(_, a,r,c)
   return matrixFromTable(a,r,c)
end
setmetatable(matrix, {__call=__call})


----
---- metamethods
----

local function __index(self, i)
   return self.vectors[i]
end
matrixMt.__index = __index

local function __newindex(self, i, v)
   self.vectors[i] = v
end
matrixMt.__newindex = __newindex

-- test for equality
local function __eq(A, B)
   local eq = A.rows == B.rows and A.columns == B.columns
   if eq then
      for i, v in A:vects() do
         eq = (v == B[i])
         if not eq then break end
      end
   end
   if eq then
      for i, v in B:vects() do
         eq = (v == A[i])
         if not eq then break end
      end
   end
   return eq
end
matrixMt.__eq = __eq


-- find A + B
local function __add(A, B)
   local rows, columns = A.rows, A.columns
   assert(rows == B.rows and columns == B.columns,
          "matrices must both be the same size")
   local C = A:copy()
   for i, v in B:vects() do
      C[i] = C[i] + v
   end
   return C
end
matrixMt.__add = __add


-- find A - B
local function __sub(A, B)
   local rows, columns = A.rows, A.columns
   assert(rows == B.rows and columns == B.columns,
          "matrices must both be the same size")
   local C = A:copy()
   for i, v in B:vects() do
      C[i] = C[i] - v
   end
   return C
end
matrixMt.__sub = __sub

local function __concat(A,v)
    return tostring(A)..tostring(v)
end
matrixMt.__concat = __concat

-- matrix multiplication

-- suppose c is a scalar, v is a vector of size n, A is a 
-- mxn matrix and B is a nxp matrix
-- 
-- operation function return value 
-- --------- -------- ------------
-- sA        smmul    a mxn matrix
-- vA          -           -
-- Av        mvmul    a vector of size m
-- AB        mmmul    a mxp matrix
--
-- __mul is the multiplication metamethod that dispatches to the 
-- appropriate function based on the type of its arguments

local function smmul(c, A)
   local B = A:copy()
   for i, v in B:vects() do
      B[i] = c * v
   end
   return B
end

local function mvmul(A, v)
   if A.columns ~= v.size then 
    log('\n'..tostring(A)..'\n'..tostring(v))
    error( "inner dimensions must agree",3) 
   end
   local w = vector.new(A.rows)
   for i, row in A:vects() do
      -- u is a row in A
      local s = rational.zero
      for j, val in row:elts() do
         s = s + v[j] * val
      end
      w[i] = s
   end
   return w
end
-- Uses the textbook column flipping algorithm, but does skip over
-- elements that are zero.
local function mmmul(A, B)
   assert(A.columns == B.rows, "inner dimensions must agree")
   local C = matrix.new(A.rows, B.columns)
   for i = 1, B.columns do
      for j, v in A:vects() do
         local p = rational.zero
         for k, e in v:elts() do
            p = p + e * B[k][i]
         end
         C[j][i] = p
      end
   end
   return C
end        

local function __mul(a, b)
   local c
   if type(a) == "number" or a.type == "rational" then
      c = smmul(a, b)
   elseif type(b) == "number" or b.type == "rational" then
      c = smmul(b, a) -- scalar multiplication is commutative
   elseif type(b) == "table" and b.type == "vector" then
      c = mvmul(a, b)
   elseif type(a) == "table" and a.type == "vector" then
      c = vmmul(a,b)
   elseif type(a) == "table" and type(b) == "table" and a.type == "matrix" and b.type == "matrix" then
      c = mmmul(a, b)
   else 
      error("multiplying a matrix by that type is not supported.")
   end
   return c
end
matrixMt.__mul = __mul


local function __div(A, c)
   assert(type(c) == "number", "matrices can only be divided by scalars")
   return smmul(1/c, A)
end
matrixMt.__div = __div


local function __tostring(self)
   local s = {}
   local rows, columns = self.rows, self.columns
   local max = 0
   local digits = 4 -- how many digits to print for each entry
   local padding = 2 -- how much padding between entries
   if rows <= 100 and columns <= 100 then
      for i = 1, rows do
         s[i] = {}
         for j = 1, columns do
            local e = tostring(self[i][j])
            s[i][j] = e
            if #e > max then max = #e end
         end
      end
      for i = 1, rows do
         for j = 1, columns - 1 do
            s[i][j] = string.format("%-"..tostring(max + padding).."s", s[i][j])
         end
         s[i][columns] = string.format("%"..tostring(max).."s", s[i][columns])
         s[i] = "| "..table.concat(s[i]).." |"
      end
      s = '\n'..table.concat(s, "\n")
   else
      s = "matrix ("..rows.."x"..columns.."; "..self:nonzero().." nonzero)"
   end
   return s
end
   
matrixMt.__tostring = __tostring

matrixMt.__concat = function(a,b)
    return tostring(a)..tostring(b)
end
----
---- prototype methods
----

local function copy(self)
   local M = matrix.new(self.rows, self.columns)
   for i, v in self:vects() do
      M[i] = v:copy()
   end
   return M
end
prototype.copy = copy

local function size(self)
   return self.rows, self.columns
end
prototype.size = size

local function vects(self)
   return pairs(self.vectors)
end
prototype.vects = vects

local function map(self, fn)
   local M = matrix.new(self.rows, self,columns)
   for i, v in self:vects() do
      for j, e in v:elts() do
         M[i][j] = fn(e, i, j)
      end
   end
   return M
end
prototype.map = map


-- Count the number of nonzero elements in a matrix.
local function nonzero(self)
   local z = 0
   for i, v in self:vects() do
      z = z + v:nonzero()
   end
   return z
end
prototype.nonzero = nonzero

-- Construct the transpose of a matrix
local function transpose(self)
   local M = matrix.new(self.columns, self.rows)
   for i, v in self:vects() do
      for j, e in v:elts() do
        if not M[j] then 
            log('attempt to assign value: '..e..'from:'..i..','..j..' to:\n'..tostring(M))
            error('missing vector #'..j,2) 
        end
         M[j][i] = e
      end
   end
   return M
end
prototype.transpose = transpose
prototype.t = transpose


-- Find the inverse of a matrix
local function inverse(self)
   local columns = self.columns
   local M = matrix.id(columns)
   for i = 1, columns do
      M[i] = matrix.gepp(self, M[i])
   end
   return M:t()
end
prototype.inverse = inverse


-- Returns with the value of the largest element in self.
local function max(self)
   local max = self[1]:max()
   for i, v in self:vects() do
      local m = v:max()
      if m > max then max = m end
   end
   return max
end
prototype.max = max


-- Returns with the value of the smallest element in self
local function min(self)
   local min = self[1]:min()
   for i, v in self:vects() do
      local m = v:min()
      if m < min then min = m end
   end
   return min
end
prototype.min = min

 
----
---- decompositions
----

-- LU decompose A into permutation matrix P, lower triangle L and
-- upper triangle P.
function matrix.lu(A)
   local rows, columns = A.rows, A.columns
   assert(rows == columns, 
          "only LU decomposing square matrices is supported")
   assert(A:nonzero() > 0, "can't LU decompose the zero matrix")
   -- Don't want to work with A directly, or its elements will be
   -- changed, and that would be bad, so make a copy of A and use that.
   local A = A:copy()
   local lambda = vector.new(rows)
   for i = 1, rows do
      lambda[i] = i
   end
   for k = 1, rows - 1 do
      local Amax = 0
      local imax = 0
      -- find the pivot position for the current column
      for i = k, rows do
         local temp = math.abs(A[i][k])
         if temp > Amax then
            Amax, imax = temp, i
         end
      end
      -- move the pivot position to the top row of the submatrix being
      -- worked on
      A[k], A[imax] = A[imax], A[k]
      -- swap entries in lambda so we remember how we permuted the rows
      lambda[k], lambda[imax] = lambda[imax], lambda[k]
      -- calculate the multipliers, and record them in A
      local Akk = A[k][k]
      for i = k + 1, rows do
         A[i][k] = A[i][k] / Akk
      end
      -- update A
      for j = k + 1, rows do
         for i = k + 1, rows do
            A[i][j] = A[i][j] - A[i][k] * A[k][j]
         end
      end
   end
   local P = matrix.new(rows, rows)
   -- create the permutation matrix P
   for i = 1, rows do
      P[lambda[i]][i] = 1
   end
   -- create L and turn A into U by zeroing out all the entries of L in A
   local L = matrix.id(rows)
   for i = 1, rows do
      for j = 1, i - 1 do
         L[i][j], A[i][j] = A[i][j], rational.zero
      end
   end
   return P, L, A
end


-- Find the Cholesky decomposition of A using inner products
function matrix.cholesky(A)
   local rows, columns = A.rows, A.columns
   assert(rows == columns, "Matrix must be square")
   local A = A:copy()
   for i = 1, rows do
      for k = 1, i -1 do
         A[i][i] = A[i][i] - (A[k][i] * A[k][i])
      end
      if A[i][i] <= 0 then 
         error("matrix is not symmetric positive definite")
      end
      A[i][i] = math.sqrt(A[i][i])
      for j = i + 1, rows do
         for k = 1, i - 1 do
            A[i][j] = A[i][j] - A[k][i] * A[k][j]
         end
         A[i][j] = A[i][j] / A[i][i]
      end
   end
   -- remove entries below the diagonal
   for i = 2, rows do
      for j = 1, i - 1 do
         A[i][j] = rational.zero
      end
   end
   return A
end


-- Givens rotation; used for QR factorization.
-- The way r, c and s is calculated here is not ideal. 
--
-- See: 
-- Anderson, Edward (2000), Discontinuous Plane Rotations and the
--   Symmetric Eigenvalue Problem. LAPACK Working Note 150, University
--   of Tennessee, UT-CS-00-454, December 4, 2000.
--   http://www.netlib.org/lapack/lawnspdf/lawn150.pdf
local function givens(A, i, j)
   local G = matrix.id(A.rows)
   local a = A[i][i]
   local b = A[j][i]
   local r = math.sqrt(a^2 + b^2)
   local c = a / r
   local s = b / r
   G[i][i] = c
   G[j][j] = c
   G[i][j] = s
   G[j][i] = -s
   return G
end


-- Find the QR decomposition of matrix A using Givens rotations.
-- Returns the orthogonal matrix Q and the upper triangular matrix R.
-- Q * R = A (not accounting for error).
function matrix.qr(A)
   local A = A:copy()
   local Q = matrix.id(A.rows)
   for j = 1, A.columns do
      for i = A.rows, j + 1, -1 do
         local G = givens(A, j, i)
         A = G * A
         A[i][j] = 0
         Q = G * Q
      end
   end
   return Q:t(), A
end



----
---- solvers (direct, for iterative, see isolv.lua)
----

-- solve Ax = b using gaussian elimination with parital pivoting
-- returns x, the vector of solutions
function matrix.gepp(A, b)
    assert(A:nonzero() > 0, "cannot % the zero matrix")
   log('solving Ax = b, A=\n'..tostring(A)..'\nb='..tostring(b))
   local rows, columns = A.rows, A.columns
   -- make a copy of A, otherwise the algorithm will modify the A that was 
   -- passed in.
   local A = A + matrix.new(rows, columns)
   local lambda = vector.new(rows)
   for i = 1, rows do
      lambda[i] = i
   end
   for k = 1, rows - 1 do
      local Amax = 0
      local imax = 0
      -- find column pivot positions
      for i = k, rows do
         local temp = rational.abs(A[i][k])
         if temp > Amax then
            Amax = temp
            imax = i
         end
      end    
      if imax ~= k then
         -- swap rows of A
         log('swapping row '..k..' with row '..imax)
         A[k], A[imax] = A[imax], A[k]
         -- swap entries in lambda to remember pivots
         lambda[k], lambda[imax] = lambda[imax], lambda[k]
         -- calculate the multipliers
      end
      local A_kk = A[k][k]
      for i = k + 1, rows do
         log("A_"..i.."_"..k.." = ".."A_"..i.."_"..k.." / A_"..k.."_"..k.."="..(A[i][k] / A_kk))
         A[i][k] = A[i][k] / A_kk
      end
      -- update A
      for j = k + 1, rows do
         for i = k + 1, rows do
            A[i][j] = A[i][j] - A[i][k] * A[k][j]
         end
      end
   end
   -- Permute the right hand side as indicated by lambda
   local bh = vector.new(rows)
   for i = 1, rows do 
      bh[i] = b[lambda[i]];
   end
   -- Solve the lower triangular system Lc = b
   local c = vector.new(rows)
   for i = 1, rows do
      local sum = bh[i]
      for j = 1, i - 1 do
         sum = sum - A[i][j] * c[j]
      end
      c[i] = sum
   end
   -- Solve the upper triangular system, Uz = c
   local z = vector.new(rows);
   for i = rows, 1, -1 do
      local sum = c[i]
      for j = i + 1, rows do
         sum = sum - A[i][j] * z[j]
      end
      if A[i][i] == 0 then
         error("the algorithm fails")
      else
         z[i] = sum / A[i][i]
      end
   end
   -- permute the z vector to get the solution x (this
   -- step is required if there were any column switches
   local x = vector.new(rows)
   for i = 1, rows do
      x[i] = z[i]
   end
   return x
end
-- Use the % operator as shorthand for gepp.
-- i.e. x = A % b to get the solutions of Ax = b
matrixMt.__mod = matrix.gepp


----
---- miscellaneous
----

-- create an nxn identity matrix
function matrix.id(n)
   local M = matrix.new(n, n)
   for i = 1, n do
      M[i][i] = rational.one
   end
   return M
end

return matrix