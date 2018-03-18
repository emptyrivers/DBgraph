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
local prototype = {type = "matrix"}
matrix.mt = matrixMt

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
   return self.vectors[i] or matrix[i]
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
   if rows <= 100 and columns <= 100 or self:nonzero() < 20 then
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


local function copy(self)
   local M = matrix.new(self.rows, self.columns)
   for i, v in self:vects() do
      M[i] = v:copy()
   end
   return M
end
matrix.copy = copy

local function size(self)
   return self.rows, self.columns
end
prototype.size = size

local function vects(self)
   return pairs(self.vectors)
end
prototype.vects = vects


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
matrix.t = transpose

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

function matrix.join(M, i, j, r)
    -- returns a matrix with 1 fewer row, such that M_new[i] = M_old[i] + r * M[j], and replace M[j] with zeros
    M[i], M[j] = M[i] + r * M[j], vector.new(M.rows)
    return M
end

return matrix
