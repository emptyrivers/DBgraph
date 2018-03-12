
-- customized implementation of Revised Simplex method

require "util"
local taskMap = require("libs.PocketWatch").taskMap
local matrix  = require "libs.matrix" 
local vector = require "libs.vector"
local logger = require "misc.logger"
local snippets = require "misc.snippets"
local inspect = require 'inspect'
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
  if state.__forwardMap[type][toMap] then return end
  table.insert(state.__inverseMap[type], toMap)
  state.__forwardMap[type][toMap] = #state.__inverseMap[type]
  logger:log(4,"log","added " .. toMap .. " to mapping at index " .. state.__forwardMap[type][toMap].. ', type '..type)
end

function taskMap.BeginProblem(timer,graph,target,guiElement)
  -- first, create problem state which will persist until the problem is solved
  logger:log(4,"console","beginning problem")
  local state = {
    u_s = {},
    w = {},
    u_it = {},
    graph = graph,
    element = guiElement,
    target = target,
    recipes = {},
    source = {},
    __forwardMap = {item = {}, recipe = {},source = {}}, --maps strings to unique id for this problem
    __inverseMap = {item = {}, recipe = {},source = {}}, --get strings back from unique id
  }
  logger:log(4,"log","initial state created")
  local queue = NewQueue()
  local b = {}
  for item, constraint in pairs(target) do
    logger:log(4,"log","adding "..item.." to queue")
    local node = graph.nodes[item]
    queue:push(node)
    AddMapping(state,item,'item')
    logger:log(4,"log", item .. ' is at')
    b[state.__forwardMap.item[item]] = constraint
  end
  state.constraintVec = vector(b)
  return timer:Do("GetProblemConstants",timer,state,queue,{node = {}, edge = {}})
end

function taskMap.GetProblemConstants(timer,state,queue,visited) -- try to construct u, w, u_s, u_it now
  local itemtoint = state.__forwardMap.item
  local recipetoint = state.__forwardMap.recipe
  local sourcetoint = state.__forwardMap.source
  for i = 1,40 do
    local node = queue:pop()
    if not node then return timer:Do("FormalizeProblem",timer,state,queue,visited) end
    log('examining: '.. node.id)
    visited.node[node.id] = true
    if node.type == "SOURCE" then
      log('this is a source node')
      state.w[sourcetoint[node.id]] = 1
    elseif table_size(node.inflow) > 0 then
      for edgeid, edge in pairs(node.inflow) do
        if edge.valid and not visited.edge[edgeid] --[[ and edge.enabled ]] then -- this is a column of u
          log('visiting '..edgeid)
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
          state.u_s[recipetoint[edgeid]] = s
          state.u_it[recipetoint[edgeid]] = it
        end
      end
    else -- if an ancestor of a target node has no parents, but is not a source, then it cannot be produced.
      log(node.id..' has rendered this infeasible.')
      return state.element:Update("infeasible",node)
    end
  end
  return timer:Do("GetProblemConstants", timer, state, queue, visited)
end

function taskMap.FormalizeProblem(timer,state)
  local q = #state.__inverseMap.item
  local p = #state.__inverseMap.source
  -- now fix constraintFunc.
  -- u_it is a protomatrix with most of the correct data, but we need to add slack coefficients
  local u_it = state.u_it
  local n = #state.__inverseMap.recipe
  local recipetoint = state.__forwardMap.recipe
  -- now constraintVec is ripe for solving
  for i = 1,q do
    local id = "@PC_SLACK@"..i
    AddMapping(state,id,'recipe')
    u_it[recipetoint[id]] = {[i] = -1}
  end
  state.constraintFunc = matrix(u_it,q + n,q) -- conveniently in column-major form, so getting the columns is easy
  state.constraintFuncbyRow = state.constraintFunc:t()
  state.constraintVec.size = q
  state.objFunc =  matrix(state.u_s, n + q, p) * vector(state.w)
  if not (state.constraintVec >= 0) then
    for i, e in state.constraintVec:elts() do
      if e < 0 then
        state.constraintFuncbyRow[i] = -1 * state.constraintFuncbyRow[i]
        state.constraintVec[i] = -e
      end
    end
    state.constraintFunc = state.constraintFuncbyRow:t()
  end
  state.basisB = q
  state.basisN = n
  do
    local B, N,  c_b, n, q = {}, {},{}, state.basisN, state.basisB
  for i = 1, n do
    N[i] = true
  end
    local A_b = matrix.new(q,q)
  for i = n + 1, n + q do
      A_b[i-n] =  state.constraintFunc[i]
    table.insert(c_b,state.objFunc[i])
    B[i] = i-n
  end
  local b = state.constraintVec
  state.A_b = A_b  -- still transposed
  state.B = B
  state.N = N
  state.A_b = A_b
  state.c_b = c_b
  end
  return timer:Do("PreSolve1", timer, state)
end

function taskMap.PreSolve1(timer,state) 
  -- problem is formalized, prepare for phase 1
  -- introduce artificial variables, such that we solve:
  -- min z
  -- sub. to A*x` = b, where x is expanded to be (x s z), s being our slack (already added)
  -- this corresponds to adding the columns of the qxq id matrix to our constraint func, and then getting
  -- the initial bfs of z = b, x = 0
  -- how big should z be? as big as b
  local n = state.constraintFunc.rows
  log('we need to find a bfs for this constraint:\n'..tostring(state.constraintFunc:t()))
  local b = state.constraintVec:copy()
  local q = b.size
  local x = vector.new(n + q)
  local c = vector.new(n + q)
  local c_b = vector.new(q)
  local A = state.constraintFunc:copy() -- remember, this representation is transposed
  A.rows = n + q
  local A_b = matrix.new(q,q)
  local basis = {}
  local nonbasis = {}
  A.rows = n + q
  for i=1, q do
    basis[i] = i + n
    x[i + n] = b[i]
    c[i + n] = 1
    c_b[i] = 1
    c[i + n] = 1
    local v = vector.new(q)
    v[i] = 1
    A.vectors[i + n] = v
    A_b.vectors[i] = v
    AddMapping(state,'@PC_ARTIFICIAL@'..i,'recipe')
  end
  log('A:\n'..tostring(A:t())..'\nA_b:\n'..tostring(A_b))
  for i = 1, n do
    nonbasis[i] = i
  end
  -- so now, x is a bfs, A is the full matrix constraint,
  -- c is the obj, b the vector constraint, A_b our basis for the bfs
  local phase1 = {
    x = x,
    c = c,
    c_b = c_b,
    A_b = A_b,
    basis = basis,
    nonbasis = nonbasis,
    b = b,
    A = A,
    A_b = A_b,
    state = state,
    phase = 1
  }
  return timer:Do("LPSolve",timer,phase1)
end




function taskMap.LPSolve(timer,state)
  --start with feasible basis B and bfs x
  log'begin another iteration'
  local B, x, c = state.basis, state.x, state.c
  log('current best: '..tostring(x)..' with score: '..x * c)
  --solve for y in A_b:t() % c_b
  local A_b, c_b = state.A_b, state.c_b  -- A_b is transposed, no need to transpose it again
  local y = A_b % c_b
  --compute c_j_next = c_j - vector.dot(A_j,y) for each j in N
  local N = state.nonbasis
  local c = state.c
  local enteringIndex, A_k
  local A = state.A
  for j in pairs(N) do
    local c_j = c[j]
    local A_j = A[j]
    local c_j_next = c_j - vector.dot(A_j,y)
    if c_j_next < 0 then
      log('new entering variable: '..j.. ' which corresponds to x_'..N[j])
      enteringIndex = j --k is entering variable
      A_k = A_j
      break
    end
  end
  if not enteringIndex then --optimal solution
    local t = {}
    local intToRecipe = state.state.__inverseMap.recipe
    for i, v in x:elts() do
      t[intToRecipe[i]] = v
    end
    log('final solution;'..inspect(t))
    error'done'
    if state.phase == 1 then
      return timer:Do("PreSolve2",timer,state)
    else
      return timer:Do("PostSolve",timer,state)
    end
  end
  -- solve for d in A_b * d = A_k
  local d = A_b:t() % A_k --want un-transposed A_b
  if d <= 0 then
    return state.element:Update("unbounded",state)
  end
  -- compute min ratio to find leaving variable
  local t,leavingIndex = math.huge
  log('searching for the best improvement:')
  log('x = '..tostring(x))
  log('d = '..tostring(d))
  for i,e in d:elts() do
    if e > 0  then
      local ratio = x[B[i]]/e
      if ratio < t then
        t = ratio
        leavingIndex = i
        log('new leaving variable: '..i.. ' which corresponds to x_'..B[i])
        log('maximum increase to x_'..N[enteringIndex].. ' is '..t)
      end
    end
  end
  -- k is entering, r is leaving
  -- replace x[k] by t and x[i] by x[i] - d[i]t
  x[N[enteringIndex]] = t
  for i, i_b in pairs(B) do
    if d[i] ~= 0 then -- no need to do the whole thing if zero
      x[i_b] = x[i_b] - d[i] * t
    end
  end
  -- update basis and c_b
  -- also need to change A_b. Store it transposed so that we can edit the row easily enough
  c_b[leavingIndex] = c[enteringIndex]
  A_b[leavingIndex] = A_k
  B[leavingIndex], N[enteringIndex] = N[enteringIndex], B[leavingIndex]
  --state.element:Update("",{})
  return timer:Do("LPSolve",timer,state)
end

function taskMap.PostSolve(timer,state)
  log(inspect(state))
  state.element:Update("finished",state)
  --return timer:Do("PostSolve",timer,state)
end


return {}
