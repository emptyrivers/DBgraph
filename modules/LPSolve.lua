
-- customized implementation of Revised Simplex method

local lib = require "lib"
local taskMap, matrix, vector = lib.PocketWatch.taskMap, lib.matrix, lib.vector

require "util"
local logger = require "misc.logger"
local snippets = require "misc.snippets"
local inspect = require 'inspect'



function AddMapping(state, toMap,type)
  if state.__forwardMap[type][toMap] then return end
  table.insert(state.__inverseMap[type], toMap)
  state.__forwardMap[type][toMap] = #state.__inverseMap[type]
end

function taskMap.BeginProblem(timer,graph,target,guiElement) --TODO: cleanup
  -- first, create problem state which will persist until the problem is solved
  local state = {
    graph = graph,
    element = guiElement,
    target = target,
    recipes = {},
    source = {},
    __forwardMap = {item = {}, recipe = {},source = {}}, --maps strings to unique id for this problem
    __inverseMap = {item = {}, recipe = {},source = {}}, --get strings back from unique id
  }
  local queue = snippets.NewQueue()
  local b = {}
  for item, constraint in pairs(target) do
    if constraint > 0 then
    local node = graph.nodes[item]
    queue:push(node)
    end
    AddMapping(state,item,'item')
    b[state.__forwardMap.item[item]] = constraint
  end
  state.b = vector(b)
  return timer:Do("GetProblemConstants",timer,state,queue,{node = {}, edge = {}}, {}, {}, {})
end

function taskMap.GetProblemConstants(timer,state,queue,visited, w, u_s, u_it) -- try to construct u, w, u_s, u_it now
  local itemtoint = state.__forwardMap.item
  local recipetoint = state.__forwardMap.recipe
  local sourcetoint = state.__forwardMap.source
  for i = 1,40 do
    local node = queue:pop()
    if not node then 
      return timer:Do("FormalizeProblem",timer,state, w, u_s, u_it) 
    end
    visited.node[node.id] = true
    if node.type == "SOURCE" then
      w[sourcetoint[node.id]] = 1
    elseif table_size(node.inflow) > 0 then
      for edgeid, edge in pairs(node.inflow) do
        if edge.valid and not visited.edge[edgeid] --[[ and edge.enabled ]] then -- this is a column of u
          local it, s = {}, {}
          visited.edge[edgeid] = true
          AddMapping(state,edgeid,'recipe')
          for product, amount in pairs(edge.products) do
            -- products cannot be sources. all of these go to it
            -- also don't queue these nodes up
            if not itemtoint[product] then
              AddMapping(state,product,'item')
            end
            it[itemtoint[product]] = amount
          end
          for ingredient, amount in pairs(edge.ingredients) do
            local node = edge.inflow[ingredient]
            if not visited.node[ingredient] then queue:push(node) end
            if node.type == "SOURCE" then
              AddMapping(state,ingredient,'source')
              s[sourcetoint[ingredient]] = amount 
            else
              AddMapping(state,ingredient,'item')
              it[itemtoint[ingredient]] = -amount
            end
          end
          -- now it and s are complete: add columns to protomatrix
          u_s[recipetoint[edgeid]] = s
          u_it[recipetoint[edgeid]] = it
        end
      end
    else -- if an ancestor of a target node has no parents, but is not a source, then it cannot be produced.
      return state.element:Update("infeasible",node)
    end
  end
  return timer:Do("GetProblemConstants", timer, state, queue, visited, w, u_s, u_it)
end

function taskMap.FormalizeProblem(timer,state, w, u_s, u_it) 
  local q = #state.__inverseMap.item
  local p = #state.__inverseMap.source
  local n = #state.__inverseMap.recipe
  local recipetoint = state.__forwardMap.recipe
  for i = 1,q do
    local id = "@PC_SLACK@"..i
    AddMapping(state,id,'recipe')
    u_it[recipetoint[id]] = {[i] = -1}
  end
  local A
  local A_t = matrix(u_it,q + n,q):t()
  local b = state.b
  b.size = q
  state.c =  matrix(u_s, n + q, p) * vector(w)
  state.flipped = {}
  for i=1,#b do
    if b[i] < 0 then -- thus, b>=0, but the slack coeff on that row might be negative if b[i] was already positive
      A_t[i] = -1 * A_t[i]
      b[i] = -b[i]
      state.flipped[i] = true
      end
    end
  A = A_t:t()
  return timer:Do("PreSolve1", timer, state, A, b)
  end

function taskMap.PreSolve1(timer,state, A, b) 

  -- obtain initial bfs for phase 1
  local recipetoint, n, m = state.__forwardMap.recipe, A:size()
  local x, c, c_b, A_b, B, N = vector.new(n), vector.new(n), vector.new(m),  matrix.new(m,m), {}, {}
  local artCounter, isBasis = 0, {}
  for i=1, m do
    local id
    if --[[ b[i] ~= 0 and ((b[i] > 0) ~= (A[i + m][i] > 0)) ]]  true then
      phase = 1
      local newVar = '@PC_ARTIFICIAL@'..artCounter
      AddMapping(state,newVar,'recipe')
      id = recipetoint[newVar]
      artCounter = artCounter + 1
      local v = vector.new(m,{[i] = 1})
      x.size, c.size, A.rows = #x + 1, #c + 1, A.rows + 1
      A.vectors[id] = v
      A_b.vectors[i] = v
      c[id] = 1 
      c_b[i] = 1
    else
      id = recipetoint["@PC_SLACK@"..i]
      A_b.vectors[i] = A.vectors[id]
    end 
    log('initial basis #'..i..' = '..id)
    isBasis[id] = true
    B[i] = id
    x[id] = b[i]
  end
  local id = 1
  for i = 1, A.rows do
    if not isBasis[i] then
      N[i] = id
      log('nonbasis #'..id..' = '..i)
      id = id + 1
    end
  end

  -- if no artificial vars necessary, then bfs is trivial and go directly to phase 2
  if phase == 2 then
    c = state.c
    for i, j in pairs(B) do
      c_b[i] = c[j]
    end
  end
  log('objective function is c='..tostring(c))
  log('constraint vector is b='..tostring(b))
  log('constraint func is A:\n'..tostring(A:t()))
  log('initial bfs is x='..tostring(x))
  log('A*x='..tostring(A:t()*x))
  log('c_b='..tostring(c_b))
  log('A_b=\n'..tostring(A_b))
  if artCounter == 0 then
    state.phase = 2
  else
    state.phase = 1
  end
  log('phase = '..state.phase)
  state.iter = 1
  return timer:Do("LPSolve",timer,state, c, x, A, b, c_b, A_b, B, N, matrix.id(m))
end


function taskMap.PreSolve2(timer,state, c, x, A, b, c_b, A_b, B, N, A_b_inv)
  local inttorecipe = state.__inverseMap.recipe
  for i = #x, 1, -1 do
    local id = inttorecipe[i]
    if id:find("^%@PC_ARTIFICIAL%@") then
      x.size = #x - 1
      A.rows, A.vectors[i] = A.rows - 1, nil
      for j,v in ipairs(N) do
        if v == i then
          table.remove(N,j)
          break
        end
      end
    else
      break
    end
  end

  c = state.c
  for i, j in pairs(B) do
    c_b[i] = c[j]
  end
  state.phase = 2
  state.iter = 1

  -- A_b is almost certainly not the identity matrix here.
  log('Phase 2: c='..tostring(c))
  return timer:Do("LPSolve",timer,state, c, x, A, b, c_b, A_b, B, N, A_b_inv)
end




function taskMap.LPSolve(timer,state, c, x, A, b, c_b, A_b, B, N, A_b_inv)
  log('iteration #:'..state.iter)
  log('best solution so far is: x='..tostring(x))
  log('best score so far is c*x='..tostring(x*c))
  log('A_b^-1=\n'..tostring(A_b_inv))
  log('c_b='..c_b)
  -- solve A_b * y = c_b
  -- A_b_inv * c_b
  local y = A_b_inv * c_b



  log('new intermediate vector y='..tostring(y))
  -- find entering var
  local k, A_k
  for j,j_n in pairs(N) do
    if c[j_n] - A[j_n] * y < 0 then
      k = j 
      A_k = A[j_n]
      break
    end
  end
  
  -- check for optimality
  if not k then
    log'solution is optimal'
    log('score is c*x ='..c*x)
    log('\n'..tostring(A:t()))
    log(tostring(b))
    log('A*x='..tostring(A:t()*x))
    if state.phase == 1 then
      if x * c <= 0 then
        return timer:Do("PreSolve2",timer,state, c, x, A, b, c_b, A_b, B, N, A_b_inv)
      else
        return state.element:Update("infeasible",state)
      end
    else
      return state.element:Update("finished", x, state.__inverseMap)
    end
  end
  log('found a new entering var k='..k..' which corresponds to x_'..N[k])

  -- solve d*A_b = A_k

  local d = A_k * A_b_inv
  log('new intermediate vector d='..tostring(d))

  local u,t,r = true, math.huge
  for i,e in d:elts() do
    if e > 0  then
      u = false
      local ratio = x[B[i]]/e
      if ratio < t then
        t = ratio
        r = i
      end
    end
  end

  -- check for unboundedness
  if u then 
    return state.element:Update("unbounded",state)
  end
  log('found a new leaving var r='..r..' which corresponds to x_'..B[r])
  log('the total increase to entering var was t='..t)

  -- update to prepare for next iteration
  -- A_b gets updated by replacing A_b[r] with A_k (thinking in columns here)
  -- so the update matrix is u*v:t(), where u = A_k - A_b[r] and v = { [r] = 1}
  -- so since our crap is all transposed, we want v*u:t()
  local v,u, vu = vector.new(#b,{[r]=1}), A_k - A_b[r], matrix.new(#b)
  A_b[r] = A_k
  log('new basis matrix:'..A_b)
  log('updating inverse using rank1 update')
  vu[r] = u
  local abv = A_b_inv * v
  log('u='..u)
  log('v='..v)
  log('vu='..vu)
  log('A^-1*v='..abv)
  local uabv = u * abv
  log('u*A^-1*v='..uabv)
  log('inverse multiplier ='..(1+uabv))
  local mul = 1/(1+uabv)
  log('multiplier='.. mul)
  local protoinv = A_b_inv * vu * A_b_inv
  log('scaled inverse ='..(protoinv))
  A_b_inv = A_b_inv - (mul * protoinv)
  c_b[r] = c[N[k]]
  x[N[k]] = t
  x[B[r]] = 0
  B[r], N[k] = N[k], B[r]
  state.iter = state.iter + 1
  for i, e in d:elts() do
    if i ~= B[r] then
      x[B[i]] = x[B[i]] - d[i] * t
    end
  end

  log('new basis is:'..inspect(B))
  log('non-basis elements are:'..inspect(N))
  log('new inverse basis matrix:'..A_b_inv)
  log('A*x='..(A:t()*x))
  return timer:Do("LPSolve",timer,state, c, x, A, b, c_b, A_b, B, N, A_b_inv)
end



return {}
