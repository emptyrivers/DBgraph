
-- customized implementation of Revised Simplex method

require "util"
local taskMap = require("lib.PocketWatch").taskMap
local matrix  = require "lib.matrix" 


function NewQueue()
  return {
    first = 0,
    last  = 0,
    pop  = function(self) --technically unsafe, but you'd have to try really hard to saturate this queue
      if self.first == self.last then return end
      local val = self[self.first]
      self[self.first] = nil
      self.first = self.first + 1
      return val
    end,
    push = function(self, toPush)
      self[self.last] = toPush
      self.last = self.last + 1
    end,
    len = function(self)
      return self.last - self.first
    end,
  }
end

function AddMapping(state, toMap,type)
  if state.__inverseMap[type][toMap] then return end
  table.insert(state.__forwardMap[type], toMap)
  state.__inverseMap[type][toMap] = #state.__forwardMap[type]
end

function taskMap.BeginProblem(timer,graph,target,guiElement)
  -- first, create problem state which will persist until the problem is solved
  local state = {
    u_s = {},
    w = {},
    u_it = {},
    graph = graph,
    element = guiElement,
    target = target,
    recipes = {},
    source = {},
    __forwardMap = {item = {}, recipe = {}}, --maps strings to unique id for this problem
    __inverseMap = {item = {}, recipe = {}}, --get strings back from unique id
  }
  local queue = NewQueue()
  local b = {}
  for item, constraint in pairs(target) do
    local node = graph.nodes[item]
    queue:push(node)
    AddMapping(state,item,'item')
    b[state.__forwardMap[item]] = constraint
  end
  state.constraintVec = vector(b)
  return timer:Do("GetProblemConstants",timer,state,stack,{node = {}, edge = {}})
end

function taskMap.GetProblemConstants(timer,state,queue,visited) -- try to construct u, w, u_s, u_it now
  local itemtoint = state.__forwardMap.item
  local recipetoint = state.__forwardMap.recipe
  for i = 1,40 do
    local node = queue:pop()
    if not node then return timer:Do("FormalizeProblem",timer,state,queue,visited) end
    visited.node[node.id] = true
    if node.type == "source" then
      state.w[itemtoint[node.id]] = 1
      elseif table_size(node.inflow) > 0 then
      for edgeid, edge in pairs(node.inflow) do
        if edge.valid and not visited.edge[edgeid] and edge.enabled then -- this is a column of u
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
            if not itemtoint[ingredient] then AddMapping(state,ingredient,'item') end
            if node.type == "source" then
              s[itemtoint[ingredient]] = amount 
            else
              it[itemtoint[ingredient]] = -amount
            end
          end
          -- now it and s are complete: add columns to protomatrix
          state.u_s[recipetoint[edgeid]] = s
          state.u_it[recipetoint[edgeid]] = it
        end
      end
    else -- if an ancestor of a target node has no parents, but is not a source, then it cannot be produced.
      return state.element:Update("infeasible",node)
    end
  end
  return timer:Do("GetProblemConstants", timer, state, queue, visited)
end

function taskMap.FormalizeProblem(timer,state)
  -- guaranteed a basic solution here
  -- want to produce:
  --[[
    state = {
      constraintVec = vector,
      objFunc = vector,
      constraintFunc = matrix,
    }
  ]]
  -- constraintVec is already produced, but its size is (possibly) wrong
  -- set r = total # of items in this problem
  -- set p = total number of source items in problem
  -- then q = r - p == total number of non-source items
  -- our constraint is that for each non-source item, we need it to be:
  -- >= target amount, if item is target, or:
  -- >= 0, if item is intermediate (i.e. neither source nor target)
  -- target constraints are already present and vector is sparse, so size just needs to be adjusted.
  local r = #state.__inverseMap.item
  local p = table_size(state.w)
  local q = r - p
  state.constraintVec.size = q
  -- now constraintVec is ripe for solving
  -- now fix constraintFunc.
  -- u_it is a protomatrix with most of the correct data, but we need to add slack coefficients
  local u_it = state.u_it
  local n = #state.__inverseMap.recipe
  local recipetoint = state.__forwardMap.recipe
  for i = 1,q do
    local id = "slack"..i
    AddMapping(state,id,'recipe')
    u_it[recipetoint[id]] = {[i] = -1} -- ultimately this adds an rxr id matrix at the right hand side, but multiplied by -1, since the constraints are all >= b instead of <= b
  end
  state.constraintFunc = matrix(u_it,q,n+q) --x has n+q variables, constraintVec has q entries
  state.constraintFuncbyColumns = state.constraintFunc:t() -- column-major
  -- now constraintFunc is ready
  -- time to set objFunc.
  -- objFunc = w * u_s
  -- w has p columns, and thus u_s has to have n + q columns, p rows
  state.objFunc =  matrix(state.u_s, p, n + q):t() * vector{w} 
  -- now we are ready
  state.basisB = q
  state.basisN = n
  return timer:Do("PreSolve", timer, state)
end

function taskMap.PreSolve(timer,state) 
  -- get a basic solution
  -- basis of constraintFunc gives us a basic solution
  local B, N, A_b, c_b, n, q = {}, {}, {},{}, state.basisN, state.basisB
  for i = 1, n do
    N[i] = true
  end
  for i = n + 1, n + q do
    table.insert(A_b, state.constraintFuncbyColumns[i])
    table.insert(c_b,state.objFunc[i])
    B[i] = i-n
  end
  A_b = matrix(A_b,q,q) -- this is transposed
  local b = state.constraintVec
  local x = A_b % b 
  state.A_b = A_b  -- still transposed
  state.x = x
  state.B = B
  state.N = N
  state.A_b = A_b
  state.c_b = c_b
  return timer:Do("LPSolve",timer,state)
end

function taskMap.LPSolve(timer,state)
  --start with feasible basis B and bfs x
  local B, x = state.B, state.x
  --solve for y in A_b:t() % c_b
  local A_b, c_b = state.A_b, state.c_b  -- A_b is transposed, no need to transpose it again
  local y = A_b % c_b
  --compute c_j_next = c_j - vector.dot(A_j,y) for each j in N
  local N = state.N
  local c = state.objFunc
  local k, A_k
  local A = state.constraintFuncbyColumns
  for j in pairs(N) do
    local c_j = c[j]
    local A_j = A[j]
    local c_j_next = c_j - vector.dot(A_j,y)
    if c_j_next < 0 then
      k = j --k is entering variable
      A_k = A_j
      break
    end
  end
  if not k then --optimal solution
    return state.element:Update("finished",state)
  end
  -- solve for d in A_b * d = A_k
  local d = A_b:t() % A_k --want un-transposed A_b
  if d <= 0 then
    return state.element:Update("unbounded",state)
  end
  -- compute min ratio to find leaving variable
  local t,r = math.huge
  for i,e in d:elts() do
    if e > 0 then
      local ratio = x[i]/e
      if ratio < t then
        t = ratio
        r = i
      end
    end
  end
  -- k is entering, r is leaving
  -- replace x[k] by t and x[i] by x[i] - d[i]t
  for i = 1, #x do
    if i == k then
      x[i] = t
    elseif d[i] ~= 0 then -- no need to do the whole thing if zero
      x[i] = x[i] - d[i] * t
    end
  end
  -- update basis
  -- also need to change A_b. Store it transposed so that we can edit the row easily enough
  A_b[B[r]] = A_k
  B[k] = B[r]
  B[r] = nil
  N[k] = nil
  N[r] = true
  return timer:Do("LPSolve",timer,state)
end

function taskMap.PostSolve(timer,state)
  for i = 1,40 do
    if state.isDone then
      return state.element:Update("finished",state)
    end
  end
  return timer:Do("PostSolve",timer,state)
end


return {}
