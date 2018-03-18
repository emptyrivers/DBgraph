-- PUMICE Copyright (C) 2009 Lars Rosengreen (-*-coding:iso-safe-unix-*-)
-- released as free software under the terms of MIT open source license

-- A sparse vector data structure.  Elements in the vector that are
-- zero use no memory.

-- to create a vector, do something like:
-- u = vector(1, 2, 3, 4)
--   -or-
-- v = vector{5, 6, 7, 8, 9}

-- to perform basic vector operations do something like:
-- w = u + v <-- addition
-- x = u - v <-- subtraction
-- x = 2 * u <-- scalar multiplication

-- internal structure of a vector
--
-- v = { size,    <-- The number of elements in vector vv.
--       type,    <-- Always "vector"; used for comparison with other tables.
--       elements <-- A table of all the elements in v.  This inner table is
--                    needed for storing elements because the __newindex
--                    metamethod only gets called when no previous entry
--                    at a given index in a table exists.  By hiding the
--                    elements in an interior table, it is possible to ensure
--                    that __newindex gets called every time a value is set.
--                    This is important because we want vectors to be sparse,
--                    so any time we set an element at a given index to 0, we 
--                    need to ensure that the actual value that gets stored is
--                    nil.  This would not be the case if a given index in
--                    the table already  had a value before being set to 0.




local vector = {}
local vectorMt = {}
local weakMt = {__mode = "kv"}
local prototype = {size = 0, type = "vector"}
local rational = require "libs.rational"

--**ADDED BY RIVERS**

----
---- constructors
----

-- create a new vector object of the given size, with a copy of the
-- flat table elements as its elements
function vector.new(size, elements)
   local elements = elements or {}
   local x = {}
   for k, v in pairs(prototype) do
      x[k] = v
   end
   x.elements = {}
   setmetatable(x, vectorMt)
   x.size = size
   for i, e in pairs(elements) do
      x[i] = rational(e)
   end
   return x
end


local function __call(_, ...)
   local args = {...}
   -- allow users to create a vector from a flat table
   if type(args[1]) == "table" then
      args = args[1]
   end
   return vector.new(#args, args)
end
setmetatable(vector, {__call=__call})


----
---- metamethods
----

local function __index(self, i)
   return self.elements[i] or rational.zero
end
vectorMt.__index = __index

local function __newindex(self, i, e)
    log('new element: '..e)
   if type(e) == 'number' then
      if e == 0 then log('it is zero, so toss it') return end
      log('nonzero :(')
      self.elements[i] = rational(e)
      return
   elseif e.n ~= 0 then 
    log('nonzero :(')
      self.elements[i] = e
      return
   end
   log('zero!')
end
vectorMt.__newindex = __newindex


-- test for equality
local function __eq(u, v)
   local eq = u.size == v.size
   if eq then
      for i, e in u:elts() do
         eq = (e == v[i])
         if not eq then break end
      end
   end
   if eq then
      for i, e in v:elts() do
         eq = (e == u[i])
         if not eq then break end
      end
   end
   return eq
end
vectorMt.__eq = __eq

-- let # operator work properly
local function __len(self)
    return self.size
end
vectorMt.__len = __len

-- check for positivity
local function __le(v,n)
    if type(n) ~= "number" then
        v,n = n,v
    end
    -- check that each element of v is <= n
    -- if n >= 0, then 0 elements are <= n trivially
    -- else, 0 elements are > n trivially
    if n < 0 then --impossible
        if v:nonzero() < #v then
            return false
        end
    else
        for i,e in v:elts() do
            if e > n then return false end
        end
    end
    return true
end
vectorMt.__le = __le

local function __lt(v,n)
    if type(n) ~= "number" then
        v,n = n,v
    end
    -- check that each element of v is <= n
    -- if n >= 0, then 0 elements are <= n trivially
    -- else, 0 elements are > n trivially
    if n <= 0 then 
        if v:nonzero() < #v then --impossible
            return false
        end
    else
        for i,e in v:elts() do
            if e >= n then return false end
        end
    end
    return true
end
vectorMt.__lt = __lt

-- find u + v
local function __add(u, v)
   if u.size ~= v.size then error("vectors must both be the same size",4) end
   local w = u:copy()
   for i, e in v:elts() do
      w[i] = w[i] + e
   end
   return w
end
vectorMt.__add = __add


local function __concat(A,v)
    return tostring(A)..tostring(v)
end
vectorMt.__concat = __concat
-- find u - v
local function __sub(u, v)
   assert(u.size == v.size, "vectors must both be the same size")
   local w = u:copy()
   for i, e in v:elts() do
      w[i] = w[i] - e
   end
   return w
end
vectorMt.__sub = __sub

local function __unm(v)
    v = v:copy()
    for i, e in v:elts() do
        v[i] = -e
    end
    return v
end
vectorMt.__unm = __unm
-- multiply vector v by a scalar or vector c
local function __mul(c, v)
   local w
   if type(c) == "number" then
      w = vector.new(v.size)
      for i, e in v:elts() do
         w[i] = c * e
      end
   elseif type(v) == "number" or v.type == "rational" then 
      w = vector.new(c.size)
      for i, e in c:elts() do
         w[i] = v * e
      end
    elseif v.type == "matrix" then
        assert(v.rows == c.size, "inner dimensions must agree")
        w = vector.new(c.size)
        for i, row in v:vects() do
            for j, val in row:elts() do
                w[j] = w[j] + val * c[i]
            end
        end
    else
      w = rational.zero
      for i, e in v:elts() do
        w = w + c[i] * e
      end
   end
   return w
end
vectorMt.__mul = __mul


-- if v is a vector and c is a constant, then return v/c = (1/c) * v
local function __div(v, c)
   local w
   if type(c) == "number" then
      w = __mul(1/c, v)
   else
      error("diving a vector by that type, or diving that type by a vector is not supported")
   end
   return w
end
vectorMt.__div = __div


local function __tostring(self)
   local s = {}
   for i = 1, self.size do
      s[i] = tostring(self[i])
   end
   return "(" .. table.concat(s, ", ") .. ")"
end
vectorMt.__tostring = __tostring

vectorMt.__concat = function(a,b)
    return tostring(a) .. tostring(b)
end
----
---- prototype methods
----

-- returns a vector that is a copy of self
local function copy(self)
   local v = vector.new(self.size)
   for i, e in self:elts() do
      v[i] = e
   end
   return v
end
prototype.copy = copy

local function size(self)
   return self.size
end
prototype.size = size

local function elts(self)
   return pairs(self.elements)
end
prototype.elts = elts

-- Maps the given function, fn(e, i) over the _non-zero_ elements of
-- self, returning the result in a new vector.  fn(e, i) can be a
-- function of one or two variables, the first is the value of a given
-- nonzero element, and i is its index.  
-- Example:
-- vector(1,0,1,13,0,0.5):map(function(e, i) return i end) would
-- return the vector (1, 0, 3, 4, 0, 6).
local function map(self, fn)
   local v = vector.new(self.size)
   for i, e in self:elts() do
      v[i] = fn(e, i)
   end
   return v
end
vector.map = map

-- Count the number of nonzero elements in a matrix.
local function nonzero(self)
   local z = 0
   for i, e in self:elts() do
      z = z + 1
   end
   return z
end
prototype.nonzero = nonzero

-- Returns the value of the largest element in self.
local function max(self)
   local max = self[1]
   for i, e in self:elts() do
      if e > max then max = e end
   end
   return max
end
prototype.max = max


-- Returns the value of the smallest element in self.
local function min(self)
   local min = self[1]
   for i, e in self:elts() do
      if e < min then min = e end
   end
   return min
end
prototype.min = min


----
---- utility functions
----

-- find the dot product of vectors u and v




return vector
