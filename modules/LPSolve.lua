
-- customized implementation of Revised Simplex method

local lib = require "lib"
local taskMap, matrix, vector = lib.PocketWatch.taskMap, lib.matrix, lib.vector

local util  =  require "util"
local logger = require "misc.logger"
local snippets = require "misc.snippets"
local inspect = require 'inspect'
local eps = 1E-7 -- this will be our "machine epsilon". Instead of checking for equality, check if difference is less than eps

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
  local     graph,               itemtoint,               recipetoint,               sourcetoint = 
    _G[graphName], state.__forwardMap.item, state.__forwardMap.recipe, state.__forwardMap.source
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
  local A_c = matrix(u_it,q, n)
  local A_r = A_c:t()
  local b = vector(state.target)
  b.size = q
  local c =  vector(w) * matrix(u_s, p, n)
  state.solutiontoitems = A_c:copy()
  local queue, Y, deleted--[[ , flipped ]] = snippets.NewQueue(), {}, {row = {}, column = {},}--[[ , {} ]]
  for r in A_r:vects() do
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
  for i = 1, n do
    table.insert(Y,vector.new(A_c.rows,{[i]=1}))
  end
  snippets.report('About to simplify:', A_c, b, c)
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
      snippets.report('simplification done, about to reduce',deleted,A_r:t(), b, c)
      return timer:Do("ReduceProblem", timer, state, deleted, A_c, b, c, Y)
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
  for i = 1, A.columns do
    if not columns[i] then
      k = k + 1
      l = 0
      for j = 1, A.rows do
        if not rows[j] then
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
      x[recipe] = math.max(x[recipe], 1/A_small[recipe][item])
    end
    log(tostring(Y_small))
    return timer:Do("PostSolve", state, x, Y_small, state.solutiontoitems)
  end
  state.decompressor= Y_small
  snippets.report('beginning problem:',A_small, b_small, c_small)
  return timer:Do("Phase1", timer, state, A_small, b_small, c_small)
end

function taskMap.Phase1(timer,state, A, b, c) 
  local m, n = A:size()
  local       x_b,          newc,           c_b,           A_b,  R,  B,  N, surplus, artificial, isBasis 
  = vector.new(m), vector.new(n), vector.new(m), matrix.new(m), {}, {}, {},      {},         {},      {}
  local j = n
  for i = 1, m do
    j = j + 1
    A[j] = vector.new(m,{[i]=-1})
    surplus[j] = true
    if b[i] > 0 then
      j = j + 1
      A[j] = vector.new(m, {[i]=1})
      artificial[j] = true
      newc[j] = 1
      c_b[i] = 1
    end
    B[i] = j
    A_b[i] = A[j]
    isBasis[j] = true
    x_b[i] = b[i]
  end
  A.columns = j
  newc.size = j
  for i = 1, A.columns do
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
  local P, P_inv, p = {}, {}
  p, state.L, state.U = matrix.lu(A_b)
  for k, v in pairs(p) do
    B[k], B[v] = B[v], B[k]
    table.insert(P, #P+1)
    table.insert(P_inv, #P)
  end
  state.P = P
  state.P_inv = P_inv
  state.b = b
  state.x_b = x_b
  state.c_b = c_b
  state.B = B
  state.N = N
  state.A = A
  state.c = newc
  state.Z = artificial
  state.R = R
  snippets.report("begin searching for reduced costs",c_b, state.P, state.L, R, state.U)
  return timer:Do("BTRAN", timer, state, c_b:copy(), state.P, state.L, R, state.U)
end

function taskMap.Phase2(timer, state)
  state.phase = 2
  state.iter = 1
  state.c, state.objective = state.objective
  for i,j in pairs(B) do
    c_b[i] = c[j]
  end
  return timer:Do("BTRAN",timer,state, c_b:copy(), state.P, state.L, state.R, state.U)
end

function taskMap.BTRAN(timer,state, y, P, L, R, U, index)
  if state.iter == 57 then error'went too long' end
  for iter = 1, 40 do
    if not index then -- solve y * U 
      log('solving y*U, y_prev='..snippets.permute(y,P))
      for k = #P, 1, -1 do
        local j = P[k]
        local column, val = U[j], y[j]
        for _, i in ipairs(P) do
          if i ~= j then
            val = val - column[i] * y[i]
          end
        end
        y[j] = val/column[j]
      end
      index = #R
    elseif index == 0 then 
      log('solving y*L, y_prev='..snippets.permute(y,P))
      for _, j in ipairs(P) do
        local column, val = L[j], y[j]
        for _, i in ipairs(P) do
          if i ~= j then
            val = val - column[i] * y[i]
          end
        end
        y[j] = val -- since L is unit triangular, we can skip the division
      end
      snippets.report("Reduced Costs found:"..y, state.N, state.c, state.A)
      return timer:Do("FindEnteringVar", timer, state, y, state.N, state.c, state.A)
    else -- solve y * Rk
      log('solving y*R, y_prev='..snippets.permute(y,P))
      local v, p = R[index].v, R[index].p
      log('R\'s row is '..v..' and is at row# '..p)
      for i, e in v:elts() do -- no need to do a permuted walk, since R is atomic
        if i ~= p then
          y[i] = y[i] + e * y[p] -- add not subtract
        end
      end
      index = index - 1
    end
  end
  return timer:Do("BTRAN", timer, state, y, L, R, U, index)
end

function taskMap.FindEnteringVar(timer, state, y, N, c, A) 
  local k, A_k
  for i, j in pairs(N) do
    local A_j = A[j]
    if c[j] - A_j * y < -eps then
      k, A_k = i, A_j
      break
    end
  end
  if not k then
    error'solution found, checklog'
    if state.phase == 1 then
      if (state.x_b * state.c_b) < eps then
        snippets.report("feasible solution found: onto phase 2", x_b, B, Z)
        return timer:Do("Phase2", timer, state, x_b, c_b, L, R, U, B, N, A, c, Z)
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
  log('\nentering variable found '..k..' which corresponds to x_'..N[k]..':'..A_k)
  snippets.report('Searching for feasible direction',A_k,state.P,state.L,state.R,state.U)
  return timer:Do("FTRAN", timer, state, k, A_k:copy(), state.P, state.L, state.R, state.U)
end

function taskMap.FTRAN(timer, state, k, d, P, L, R, U, index)
  for iter = 1,20 do
    if not index then
      -- solve L * d
      log('solving L*d, d_prev='..snippets.permute(d,P))
      for _, j in ipairs(P) do
        local column, r = L[j], d[j] -- L is unit triangular, so no need to divide
        for _, i in ipairs(P) do
          if i ~= j then
            d[i] = d[i] - column[i] * r
          end
        end
      end
      index = 1
    elseif index > #R then
      -- solve U * d
      log('solving U*d, d_prev='..snippets.permute(d,P))
      for k = #P, 1, -1 do
        local j = P[k]
        local column, r = U[j], d[j]/U[j][j]
        for _, i in ipairs(P) do
          if i ~= j then
            d[i] = d[i] - column[i] * r
          else
            d[i] = r
          end
        end
      end
      snippets.report('\nfeasible direction found, finding maximum distance and leaving var',d, state.x_b)
      return timer:Do("FindLeavingVar", timer, state, k,  d, state.x_b)
    else
      log('solving R*d, d_prev='..snippets.permute(d,P))
      -- solve R * d
      local v, p = R[index].v, R[index].p
      log('this row eta matrix has row #'..p..' = '..v)
      for i, e in v:elts() do
        if i ~= p then
          d[p] = d[p] + e * d[i] -- add, not subtract
        end
      end
      index = index + 1
    end
  end
  return timer:Do("FTRAN", timer, state, k, d, P, L, R, U, index)
end

function taskMap.FindLeavingVar(timer, state, k, d, x_b)
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
  log("leaving var found "..r..' which corresponds to x_'..state.B[r])
  log('maximum increase is '..t)
  return timer:Do("UpdateBasis", timer, state, t, r, k, d, state.x_b, state.c_b,
                state.B, state.N, state.Z, state.P, state.P_inv, state.R, state.U)
end

function taskMap.UpdateBasis(timer, state, t, r, k, d, x_b, c_b, B, N, Z, P, P_inv, R, U)
  -- update solution
  state.iter = state.iter + 1
  if t > eps then
    for i, e in d:elts() do
      if not Z[i] and i ~= r then
        x_b[i] = x_b[i] - t * e
      end
    end
  end
  B[r], N[k] = N[k], (not Z[r]) and B[r] or nil
  c[b] = state.c[k]
  -- update factorization of basis
  local p_r, shouldPermute = P_inv[r]
  log('checking to see if nonzero below '..p_r..':'..snippets.permute(d,P))
  for i in d:elts() do
    if P_inv[i] > p_r then
      shouldPermute = true
      break
    end
  end
  if shouldPermute then
    log('permutation required')
    local shouldAddFactor
    log('checking to see if new R factor required:'..snippets.permute(U,P))
    -- we require a new R factor if the 
    for k = #P, p_r + 1, -1 do
      local j = P[k]
      if U[j][p_r] ~= 0 then
        log('U['..j..']['..p_r..'] = '..U[j][p_r]..' ~=0')
        shouldAddFactor = true
        break
      end
    end
    if shouldAddFactor then
      -- solve t * U = {[p_r] = U_rr}
      -- this is backwards substitution
      local t = vector.new(#P, {[r] = U[p_r][p_r]})
      log('Urr='..U[p_r][p_r])
      for k = #P, 1, -1 do
        local j = P[k]
        local column, val = U[j], t[j]
        for _, i in ipairs(P) do
          if i ~= j then
            val = val - column[i] * t[i]
          end
        end
        t[j] = val/column[j]
      end
      log('solution to t*U = eta found:'..t)
      local newR = matrix.id(#P)
      for i, e in t:elts() do
        if P_inv[i] ~= p_r then
          newR[i][p_r] = -e
        end
      end
      log('new R factor found:'..newR)
      table.insert(R, {v = t, p = p_r, m = newR})
      d[p_r] = t * d
      log('Urr replaced with '..d[p_r])
      for _, j in ipairs(P) do
        local column = U[j]
        if j ~= p_r then
          column[p_r] = 0
        end
      end
    end
    -- update permutation
    table.insert(P, table.remove(P, p_r))
    table.insert(P_inv, p_r, table.remove(P_inv))
  end
  local shouldRefactor
  for _, e in d:elts() do
    if e > 1E5 then
      shouldRefactor = true
      break
    end
  end
  if shouldRefactor then
    local A, m, p = state.A matrix.new(#P)
    for i, j in ipairs(B) do
      m[i] = A[j]
    end
    state.P, state.P_inv, state.R, p, state.L, state.U = {}, {}, {}, matrix.lu(m)
    for k, v in pairs(p) do
      B[k], B[v] = B[v], B[k]
      table.insert(state.P, #state.P+1)
      table.insert(state.P_inv, #state.P)
    end
  else
    U[p_r] = d
  end
  snippets.report('Basis Updated', B, N, P, R[#R] and (R[#R].p ..R[#R].v) or 'no added factor', U, 'updated solution:'..x_b)
  log('permuted U is:'..snippets.permute(U,P))
  return timer:Do("BTRAN", timer, state, c_b:copy(), P, state.L, R, U)
end

function taskMap.PostSolve(state, solution, decompressor, solutiontoitems)
  local recipesUsed =  solution * decompressor
  log('recipes used:'.. recipesUsed)
  local itemsProduced = solutiontoitems * recipesUsed
  log('items produced:'..itemsProduced)
  return state.element:Update("finished", state.__inverseMap, recipesUsed, itemsProduced)
end

return {}
