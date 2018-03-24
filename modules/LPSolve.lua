
-- customized implementation of Revised Simplex method

local lib = require "lib"
local taskMap, matrix, vector = lib.PocketWatch.taskMap, lib.matrix, lib.vector

local util  =  require "util"
local logger = require "misc.logger"
local snippets = require "misc.snippets"
local inspect = require 'inspect'

local function AddMapping(state, toMap,type)
  if state.__forwardMap[type][toMap] then return end
  table.insert(state.__inverseMap[type], toMap)
  state.__forwardMap[type][toMap] = #state.__inverseMap[type]
end

function taskMap.BeginProblem(timer,graphName,target,guiElement) 

  local state = { --state is for things which won't be edited during the current stage of the problem
    element = guiElement,
    __forwardMap = {item = {}, recipe = {}, source = {}, compressed ={}},
    __inverseMap = {item = {}, recipe = {}, source = {}, compressed ={}}, 
  }

  local queue, b, graph = snippets.NewQueue(), {}, _G[graphName]
  for item, constraint in pairs(target) do
    if constraint > 0 then
      queue:push(item)
    end
    AddMapping(state,item,'item')
    b[state.__forwardMap.item[item]] = constraint
  end
  state.target = b
  local visited, w, u_s, u_it = {node = {}, edge = {}}, {}, {}, {}
  return timer:Do("GetProblemConstants",timer,state,graphName,queue,visited, w, u_s, u_it)
end

function taskMap.GetProblemConstants(timer, state, graphName, queue, visited, w, u_s, u_it) 
  local graph, itemtoint, recipetoint, sourcetoint = _G[graphName], state.__forwardMap.item, state.__forwardMap.recipe,state.__forwardMap.source
  for i = 1,40 do
    local nodeid = queue:pop()
    if not nodeid then return timer:Do("BuildDataStructs",timer,state, w, u_s, u_it) end
    local node = graph.nodes[nodeid]
    visited.node[node.id] = true
    if node.type == "SOURCE" then
      w[sourcetoint[node.id]] = 1
    elseif table_size(node.inflow) > 0 then
      for edgeid, edge in pairs(node.inflow) do
        if edge.valid and not visited.edge[edgeid] then 
          AddMapping(state,edgeid,'recipe')
          visited.edge[edgeid] = true
          local it, s = {}, {}
          for product, amount in pairs(edge.products) do
            if not itemtoint[product] then AddMapping(state,product,'item') end
            it[itemtoint[product]] = amount
          end
          for ingredient, amount in pairs(edge.ingredients) do
            local node = edge.inflow[ingredient]
            if not visited.node[ingredient] then queue:push(node.id) end
            if node.type == "SOURCE" then
              if not sourcetoint[ingredient] then AddMapping(state,ingredient,'source') end
              s[sourcetoint[ingredient]] = amount 
            else
              if not itemtoint[ingredient] then AddMapping(state,ingredient,'item') end
              it[itemtoint[ingredient]] = -amount
            end
          end
          u_s[recipetoint[edgeid]] = s
          u_it[recipetoint[edgeid]] = it
        end
      end
    else 
      local fakeSource = "@PC_SOURCE@"..node.id
      AddMapping(state,fakeSource,"source")
      local fakeRecipe = "@PC_SOURCE@"..node.id
      AddMapping(state,fakeRecipe,"recipe")
      w[sourcetoint[fakeSource]] = math.huge
      u_it[recipetoint[fakeRecipe]] = {[itemtoint[node.id]]=1}
      u_s[recipetoint[fakeRecipe]] = {[sourcetoint]=1}
    end
  end
  return timer:Do("GetProblemConstants",timer, state, graphName, queue, visited, w, u_s, u_it)
end

function taskMap.BuildDataStructs(timer,state, w, u_s, u_it)
  local q, p, n = #state.__inverseMap.item, #state.__inverseMap.source, #state.__inverseMap.recipe
  local A_c = matrix(u_it,n,q)
  local A_r = A_c:t()
  local b = vector(state.target)
  b.size = q
  local c =  matrix(u_s, n, p) * vector(w)
  state.solutiontoitems = A_r:copy()
  local queue, Y, deleted--[[ , flipped ]] = snippets.NewQueue(), {}, {row = {}, column = {},}--[[ , {} ]]
  for r, row in A_r:vects() do
    if not state.target[r] then
      queue:push(r)
    end
    --[[ if b[r].n < 0 then
      A_r[r] = -row
      for i, e in row:elts() do
        e = -e
        row[i], A_c[i][r] = e, e
      end
      b[r] = -b[r]
      flipped[r] = true
    end ]]
  end
  --state.flipped = flipped
  for i = 1, A_c.rows do
    table.insert(Y,vector.new(A_c.rows,{[i]=1}))
  end
  return timer:Do("Simplify", timer, state, queue, deleted, A_r, A_c, b, c, Y)
end

local function simpleTransfer(v, deleted) 
  local pos, neg
  for i, e in v:elts() do
    if not deleted[i] then
      if e > 0 then 
        if pos then 
          pos = false
        elseif pos == nil then
          pos = i
        end
      else
        if neg then
          return pos, false
        else
          neg = i
        end
      end
    end
  end
  return pos, neg
end

local function simpleFeed(v, known, A, deleted, target)
  local r = 0
  for i, e in v:elts() do
    if target[i] then return end
    if not deleted.row[i] and e > 0 then 
      for j, f in A[i]:elts() do 
        if f < 0 then 
          if j ~= known then return end
          r = math.max(r, -f/e)
        end
      end
    end
  end
  return r
end

function taskMap.Simplify(timer, state, queue, deleted, A_r, A_c, b, c, Y)
  for i = 1, 40 do
    local r = queue:pop()
    if not r then
      return timer:Do("ReduceProblem", timer, state, deleted, A_r, b, c, Y)
    end
    row = A_r[r]
    local prod, cons = simpleTransfer(row,deleted.column)
    if prod and cons then
      local column = A_c[prod]
      local feed = simpleFeed(column, cons, A_r, deleted, state.target)
      if feed then
        A_c[cons] = A_c[cons] + feed * A_c[prod]
        Y[cons]= Y[cons] + feed * Y[prod]
        c[cons]= c[cons] + feed * c[prod]
        deleted.row[r], deleted.column[prod] = true, true
        for i,e in column:elts() do
          A_r[i][prod] = 0
          A_r[i][cons] = A_c[cons][i]
          if not deleted.row[i] and not state.target[i] then
            queue:push(i)
          end
        end
      end
    elseif pos == false then -- that row is deleted already
      deleted.row[r] = true
    end
  end
  return timer:Do('Simplify', timer, state, queue, deleted, A_r, A_c, b, c, Y)
end

local function IsProblemTrivial(target, A) 
  local targetSeen = {}
  for i, recipe in A:vects() do
    local contributesToTarget
    for j, val in recipe:elts() do
      if val > 0 and target[j] then
        if targetSeen[j] then return end 
        targetSeen[j] = i
        contributesToTarget = true
      end
    end
    if not contributesToTarget then return end 
  end
  return targetSeen
end

function taskMap.ReduceProblem(timer, state, toRemove, A, b, c, Y)
  local columns, rows = toRemove.column, toRemove.row
  local A_small = matrix.new(A.rows - table_size(rows), A.columns - table_size(columns))
  local k, l = 0,0
  for i = 1, A.rows do
    if not rows[i] then
      k = k + 1
      l = 0
      for j = 1, A.columns do
        if not columns[j] then
          l = l + 1
          A_small[k][l] = A[i][j]
        end
      end
    end
  end
  local b_small,j = vector.new(#b - table_size(rows)),0
  for i=1,#b do
    if not rows[i] then
      j = j + 1
      b_small[j] = b[i]
    end
  end
  local c_small,j = vector.new(#c-table_size(columns)), 0
  for i=1,#c do
    if not columns[i] then
      j = j + 1
      c_small[j] = c[i]
    end
  end
  local Y_small,j = matrix.new(#c_small, #c), 0
  for i=1,#c do
    if not columns[i] then
      j = j + 1
      Y_small[j] = Y[i]
    end
  end 
  local solution = IsProblemTrivial(state.target, A_small) 
  if solution then
    local x = vector.new(A_small.columns)
    for item, recipe in pairs(solution) do
      x[recipe] = mak.max(x[recipe], 1/A_small[recipe][item])
    end
    log(tostring(Y_small))
    return timer:Do("PostSolve", state, x, Y_small, state.solutiontoitems)
  end
  state.decompressor= Y_small
  return timer:Do("Phase1", timer, state, A_small:t(), b_small, c_small)
end

function taskMap.Phase1(timer,state, A, b, c) 
  local n, m = A:size()
  local x_b, newc, c_b, A_b, A_b_inv, B, N, surplus, artificial, isBasis = vector.new(m), vector.new(n), vector.new(m),  matrix.new(m), matrix.new(m), {}, {}, {}, {}, {}
  local j = n
  for i = 1, m do
    j = j + 1
    A[j] = vector.new(m,{[i]=-1})
    surplus[j] = true
    if b[i] ~= 0 then
      j = j + 1
      A[j] = vector.new(m, {[i]=1})
      artificial[j] = true
      newc[j] = 1
      c_b[i] = 1
    end
    B[i] = j
    A_b[i] = A[j]
    A_b_inv[i] = A[j]:copy()
    isBasis[j] = true
    x_b[i] = b[i]
  end
  A.rows = j
  newc.size = j
  for i = 1, A.rows do
    if not isBasis[i] then
      table.insert(N,i)
    end
  end
  state.phase = 1
  if j == m + n then
    state.phase = 2
    newc = c
    for i, j in pairs(B) do
      c_b[i] = c[j]
    end
  else
    state.objective = c
  end
  state.iter, state.surplus = 1, surplus
  snippets.report("Prepared for LP algorithm:", x_b, c_b, A_b, A_b_inv, B, N, A, newc, artificial)
  return timer:Do("FindEnteringVar", timer, state, x_b, c_b, A_b, A_b_inv, B, N, A, newc, artificial)
end

function taskMap.Phase2(timer, state, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
  state.phase = 2
  state.iter = 1
  c, state.objective = state.objective
  for i,j in pairs(B) do
    c_b[i] = c[j]
  end
  return timer:Do("FindEnteringVar",timer,state, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
end

function taskMap.FindEnteringVar(timer, state, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
  local y = A_b_inv * c_b
  local k, A_k
  for i, j in pairs(N) do
    local A_j = A[j]
    if c[j] - A_j * y < 0 then
      k, A_k = i, A_j
      break
    end
  end
  if not k then
    if state.phase == 1 then
      if (x_b * c_b).n == 0 then
        snippets.report("feasible solution found: onto phase 2", x_b, B, Z)
        return timer:Do("Phase2", timer, state, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
      else
        return state.element:Update("infeasible")
      end
    else
      local x, decompressor, solutiontoitems = vector.new(state.decompressor.rows), state.decompressor, state.solutiontoitems
      for i,j in pairs(B) do
        x[j] = x_b[i]
      end
      snippets.report("Solution found:", x, decompressor, solutiontoitems)
      return timer:Do("PostSolve", state, x, decompressor, solutiontoitems)
    end
  end
  snippets.report("Entering var found: ", k, A_k)
  return timer:Do("FindLeavingVar", timer, state, k, A_k, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
end

function taskMap.FindLeavingVar(timer, state, k, A_k, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
  local d = A_k * A_b_inv
  local u, t, r = true, math.huge
  for i,e in d:elts() do
    if e > 0 then
      u = false
      local ratio = x_b[i]/e
      if ratio < t then
        t, r = ratio, i
      end
    end
  end
  if u then
    return state.element:Update("unbounded")
  end
  log('increase this step has ratio: '..t)
  snippets.report("leaving var found: ", t, r, d)
  return timer:Do("UpdateBasis", timer, state, t, r, k, d, A_k, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
end

function taskMap.UpdateBasis(timer, state, t, r, k, d, A_k, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
  local v, u, vu = vector.new(#x_b,{[r]=1}), A_k-A_b[r], matrix.new(#x_b)
  vu[r] = u
  A_b_inv = A_b_inv - ((1/(1+(u * (A_b_inv * v))) ) * (A_b_inv * vu * A_b_inv))
  if t.n ~= 0 then
    for i, e in d:elts() do
      if not Z[i] and i ~= r then
        x_b[i] = x_b[i] - t * e
      end
    end
  end
  state.iter, x_b[r], c_b[r], B[r], N[k], A_b[r] = state.iter + 1, t, c[N[k]], N[k], not Z[B[r]] and B[r] or nil, A_k
  snippets.report("basis updated", A_b, A_b_inv, x_b, c_b, B, N, Z)
  return timer:Do("FindEnteringVar", timer, state, x_b, c_b, A_b, A_b_inv, B, N, A, c, Z)
end

function taskMap.PostSolve(state, solution, decompressor, solutiontoitems)
  local recipesUsed =  solution * decompressor
  log('recipes used:'.. recipesUsed)
  local itemsProduced = solutiontoitems * recipesUsed
  log('items produced:'..itemsProduced)
  return state.element:Update("finished", state.__inverseMap, recipesUsed, itemsProduced)
end

return {}
