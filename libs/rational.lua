
-- rational number type
-- used because there's some really catastrophic cancellation precision loss with LP, since i'm subtracting floats a great deal
-- this will keep things exact
-- structure:
-- a rational number r is a table with the rationalMt metatable
-- supports add, sub, mul, div, unm, eq, lt, le, tostring, and concat meta events
-- r.type == "rational"
-- r.n is an integer, r.d is a positive integer, and gcd(r.n,r.d) == 1
-- r represents the rational number r.n/r.d
-- rational.one is a shortcut for rational(1), similarly for rational.zero/rational(0)
-- rational.eval returns a native floating point number equivalent
-- rational.rationalize gives a rational approximation, maximum error 1 part in 1260
-- rational.integerize takes a table of rationals and returns a table with the rationals replaced by integers, such that the ratios between the numbers is unchanged

-- unfortunately, due to the fact that we are not using hardware types, this becomes much slower
-- may think of a better solution

local rational = {}
local rationalMt = {}
local weakMt = {__mode = "kv"}
rational.mt = rationalMt
local floor = math.floor

local function gcd(a,b) --native int only!
  if a == math.huge or b == math.huge then
    return 1
  elseif b ~= 0 then
		return gcd(b, a % b)
  else
		return math.abs(a)
	end
end

local function lcm(a,b) --native int only!
  if a == 0 or b == 0 then
    return 0
  else
    return a * b / gcd(a,b)
  end
end

function rational:Init()
  rational.zero = rational(0)
  rational.one = rational(1)
  global.rationalnan = setmetatable({
    n = 0,
    d = 0,
    type = 'rational',
    nan = true,
  }, rationalMt)
  global.rationalinf = setmetatable({
    n = 1,
    d = 0,
    type = 'rational',
  }, rationalMt)
  rational.nan = global.rationalnan
  rational.inf = global.rationalinf
end

function rational:Load()
  rational.nan = setmetatable(global.rationalnan, rationalMt)
  rational.inf = setmetatable(global.rationalinf, rationalMt)
end


function rational.new(a,b,isNaN)
  local n,d = floor(a), floor(b or 1)
  local div = gcd(n,d)
  if div ~= 1 then
    n,d = n/div, d/div
  end
  if d < 0 then
    n,d = -n, -d
  end
  local r = setmetatable({
    n = n,
    d = d,
    type = "rational",
  }, rationalMt)
  if not getmetatable(r) then error("wtf",2) end
  if d == 0 and n == 0 then
    r.nan = true
  end
  return r
end

function rational.rationalize(r)
  return rational(1260*r, 1260) -- use 1260 because it is highly composite and likely to reduce, see https://en.wikipedia.org/wiki/Highly_composite_number
end

function rational.eval(a)
  return a.n/a.d
end

function rational.integerize(t) --takes table of rational numbers and returns table of integers with the same ratios
  local mul = 1
  for _,r in pairs(t) do
    mul = lcm(mul,r.d)
  end
  local res = {mul = mul}
  for k,r in pairs(t) do
    res[k] = r.n * mul
  end
  return res
end
function rational.abs(r)
  if r.n < 0 then
    return rational(-r.n,r.d)
  else
    return rational.copy(r)
  end
end
function rational.copy(r)
  return rational(r.n,r.d,r.nan)
end

function rational.min(a,b)
  return a < b and a or b
end

function rational.max(a,b)
  return a > b and a or b
end
setmetatable(rational,{
  __call = function(self,n,d)
    if type(n) == "table" and n.type == "rational" then return n end
    return self.new(n,d)
  end
})

function rationalMt.__add(a,b) --a+b
  if type(a) == 'number' then -- b must be rational
    return rational(a * b.d + b.n,b.d,b.nan)
  elseif type(b) == 'number' then -- a must be rational
    return rational(b * a.d + a.n,a.d,a.nan)
  elseif b.type == "rational" and a.type == "rational" then
    return rational(a.d*b.n + a.n*b.d,a.d*b.d,a.nan or b.nan)
  end
end
function rationalMt.__sub(a,b) --a-b
  -- n0/d0 - n1/d1 == (n0d1 - n1d0)/d0d1
  if type(a) == 'number' then -- b must be rational
    return rational(a * b.d - b.n,b.d,b.nan)
  elseif type(b) == 'number' then -- a must be rational
    return rational(b * a.d - a.n,a.d,a.nan)
  elseif b.type == a.type then --both must be rational
    return rational(a.n*b.d - a.d*b.n ,a.d*b.d,a.nan or b.nan)
  end
end
function rationalMt.__mul(a,b) --a*b
  if not a then error("?",3) end
  if type(a) == "number" then -- b must be rational
    return rational(a*b.n,b.d,b.nan)
  elseif type(b) == 'number' then -- a must be rational
    return rational(a.n*b,a.d, a.nan)
  elseif a.type == b.type then -- a and b are both rational
    return rational(a.n*b.n,a.d*b.d, a.nan or b.nan)
  else -- b must not be rational, since left arg's metamethod gets called
    return b * a
  end
end
function rationalMt.__div(a,b) --a/b
  if type(a) == "number" then -- b must be rational, a/b = a/(n/d) = a*d/n
    return rational(a*b.d,b.n, b.nan)
  elseif type(b) == 'number' then -- a must be rational
    return rational(a.n,a.d*b, a.nan)
  elseif a.type == b.type then -- a and b are both rational
    return rational(a.n*b.d,a.d*b.n, a.nan or b.nan)
  else -- b must not be rational, since left arg's metamethod gets called
    error('cannot divide a rational by a '..b.type)
  end
end
function rationalMt.__unm(a)  --(-a)
  return rational(-a.n,a.d,a.nan)
end
function rationalMt.__tostring(a) --tostring(a)
  if a.nan then
    return 'nan'
  elseif a.d == 1 then 
    return tostring(a.n) 
  elseif a.d == 0 then --inf or nan
    if a.n > 0 then
      return "inf"
    elseif a.n < 0 then
      return "-inf"
    end
  end
  return ("%s/%s"):format(a.n,a.d)
end
function rationalMt.__concat(a,b) --a..b
  return tostring(a)..tostring(b)
end
function rationalMt.__eq(a,b) --a==b
  return a.n == b.n and a.d == b.d and not (a.nan or b.nan)
end
function rationalMt.__lt(a,b) --a<b
  if type(a) == "number" then
    return a * b.d < b.n and not b.nan
  elseif type(b) == "number" then 
    return a.n < b*a.d and not a.nan
  elseif a.type == b.type then
    return a.n*b.d < a.d*b.n and not (a.nan or b.nan)
  else
    error("comparison is not supported for this type",2)
  end
end
function rationalMt.__le(a,b) --a<=b
  if type(a) == "number" then
    return a * b.d <= b.n and not b.nan
  elseif type(b) == "number" then 
    return a.n <= b*a.d and not a.nan
  elseif a.type == b.type then
    return a.n*b.d <= a.d*b.n and not (a.nan or b.nan)
  else
    error("comparison is not supported for this type",2)
  end
end
return rational
