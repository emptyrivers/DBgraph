
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
  logger:log(4,"log","added " .. toMap .. " to mapping at index " .. state.__forwardMap[type][toMap].. ', type '..type)
end

function taskMap.BeginProblem(timer,graph,target,guiElement) --TODO: cleanup
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
  local queue = snippets.NewQueue()
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

function taskMap.FormalizeProblem(timer,state) --TODO:cleanup
  local q = #state.__inverseMap.item
  local p = #state.__inverseMap.source
  -- now fix constraintFunc.
  -- u_it is a protomatrix with most of the correct data, but we need to add slack coefficients
  local u_it = state.u_it
  local n = #state.__inverseMap.recipe
  local recipetoint = state.__forwardMap.recipe
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

  local n,m = state.constraintFunc:size()
  local recipetoint = state.__forwardMap.recipe

  local b, A = state.constraintVec:copy(),state.constraintFunc:copy()
  local q = b.size
  local x, c, c_b, A_b = vector.new(n + q), vector.new(n + q), vector.new(q),  matrix.new(q,q)
  local B, N = {}, {}

  local artCounter, phase,isBasis = 1, 2, {}
  for i=1, q do
    local id
    if b[i] ~= 0 and ((b[i] > 0) ~= (A[i + m][i] > 0)) then
      phase = 1
      local newVar = '@PC_ARTIFICIAL@'..artCounter
      AddMapping(state,newVar,'recipe')
      id = recipetoint[newVar]
      artCounter = artCounter + 1
      local v = vector.new(q)
      v[i] = 1
      A.vectors[id] = v
      A_b.vectors[id] = v
      A.rows = A.rows + 1
    else
      id = recipetoint["@PC_SLACK@"..i]
    end 
    isBasis[id] = true
    B[i] = id
    x[id] = b[i]
    c[id] = 1
    c_b[i] = 1
    c[id] = 1
  end


  local id = 1
  for i = 1, A.rows do
    if not isBasis[i] then
      N[i] = id
      id = id + 1
    end
  end

  if phase == 1 then
    c = state.objFunc
    for i, j in pairs(B) do
      c_b[i] = c[j]
    end
  end

  return timer:Do("LPSolve",timer,state, c, x, A, b, c_b, A_b, B, N, phase)
end


function taskMap.PreSolve2(timer,state, c, x, A, b, c_b, A_b, B, N)

  local inttorecipe = state.__inverseMap.recipe
  for i = #x, 1, -1 do
    local id = inttorecipe[i]
    if id:find("^%@PC_ARTIFICIAL%@") then
      x.size = #x - 1
      x[i] = 0
      A.rows = A.rows - 1
      A.vectors[i] = nil
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

  c = state.objFunc
  for i, j in pairs(B) do
    c_b[i] = c[j]
  end

  return timer:Do("LPSolve",timer,state, c, x, A, b, c_b, A_b, B, N, 2)
end

function taskMap.LPSolve(timer,state, c, x, A, b, c_b, A_b, B, N, phase)

  -- find entering var
  local y, k, A_k = A_b % c_b
  for j in pairs(N) do
    if c[j] - vector.dot(A[j],y) < 0 then
      k = j 
      A_k = A[j]
      break
    end
  end
  
  -- check for optimality
  if not k then
    if state.phase == 1 then
      if x * c == 0 then
        return timer:Do("PreSolve2",timer,state, c, x, A, b, c_b, A_b, B, N)
      else
        return state.element:Update("infesible",state)
      end
    else
      return state.element:Update("finished", x, state.__inverseMap)
    end
  end

  -- find leaving var
  local d,u,t,r = A_b:t() % A_k, true, math.huge
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

  -- update state
  c_b[r] = c[k]
  A_b[r] = A_k
  x[N[k]] = t
  x[B[r]] = 0
  B[r], N[k] = N[k], B[r]
  for i, e in d:elts() do
    if i ~= k then
      x[i_b] = x[i_b] - d[i] * t
    end
  end

  return timer:Do("LPSolve",timer,state, c, x, A, b, c_b, A_b, B, N, phase)
end



return {}
