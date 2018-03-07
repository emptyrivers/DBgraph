


require "util"
local taskMap = require("modules.PocketWatch").taskMap


local function queue()
  return {
    first = 0,
    last  = 1,
    pop  = function(self) --technically unsafe, but you'd have to try really hard to saturate this queue
      local val = self[self.first]
      if val then
        self[self.first] = nil
        self.first = self.first + 1
    end
      return val
  end,
    push = function(self, toPush)
      self[self.last] = toPush
      self.last = self.last + 1
  end,
  __sub = function(a,b)
    if a.rows ~= b.rows or a.columns ~=b.columns then
      error("attempt to add mismatching matrices",2)
    end
    local r = Matrix:New(a.rows,b.columns)
    for i = 1, a.rows do
      for j = 1, a.columns do
        r[i][j] = a[i][j] - b[i][j]
      end
    end
    return r
  end,
  __mul = function(a,b)
    if a.columns ~= b.columns then
      error("attempt to multiply mismatching matrices",2)
    end
    local r = Matrix:New(a.rows,b.columns)
    for i = 1,a.rows do
      for j = 1,b.columns do
        local r = 0
        for k = 1,a.columns do
          r = r + a[i][k] * a[k][j]
        end
        r[i][j] = r
      end
    end
    return r
  end,
  __len = function(a) return a.rows end --is this really necessary?
}
local weakMt = { __mode = "kv" }


function LPSolve:Init()
  global.matrices = setmetatable({}, weakMt)
end

function LPSolve:Load()
  setmetatable(global.matrices, weakMt)
  for _, matrix in pairs(global.matrices) do
    setmetatable(matrix, matrixMt)
  end
end

-- array of rows, each row is the same length

function Matrix:New(rows,columns) -- gives the zero matrix for r,c size
  local matrix = {
    rows = rows,
    columns = coluns,
  }
  for i=1,rows do
    local t = {}
    for j = 1,columns do
      t[j] = 0
    end
    matrix[i] = t
  end
  table.insert(global.matrices, matrix)
  return setmetatable(matrix, matrixMt)
end

function matrix:AddRows(toAdd)
  for offset, row in ipairs(toAdd) do
    if #row > self.columns then
      for i = self.columns + 1, #row do
        row[i] = nil
      end
    else
      for i = #row + 1, self.columns do
        row[i] = 0
      end
    end
    self[self.rows + offset] = row
  end
  self.rows = self.rows + #toAdd
  return self
end

function Matrix:AddColumns(toAdd)
  for offset, column in ipairs(toAdd) do
    if #column < self.rows then
      for i = self.rows + 1, #column do
        column[i] = nil
      end
    else
      for i = #column + 1, self.rows do
        column[i] = 0
      end
    end
    local j = self.columns + offset
    for i, v in ipairs(column) do
      self[i][j] = v
    end
  end
  self.columns = self.columns + #toAdd
  return self
end

function Matrix:RemoveRows(toRemove)
  for i = #toRemove, 1, -1 do
    table.remove(self,i)
  end
  self.rows = self.rows - #toRemove
  return self
end

function Matrix:RemoveColumns(toRemove)
  for i = #toRemove, 1, -1 do
    for _, row in ipairs(self.rows) do
      table.remove(row, i)
    end
  end
  self.columns = self.columns - #toRemove
  return self
end

function Matrix:Transpose()
  local r = self:New(self.columns, self.rows)
  for i, row in ipairs(self.rows) do
    for j, val in ipairs(row) do
      r[j][i] = val
    end
  end
  return r
end

function taskMap.SolveChain(timer,target,guiElement)
  -- 
  local state = {
    element = guiElement,
    target = target,
    recipes = {},
    source = {},
    __forwardMap = {}, --maps strings to unique id for this problem
    __inverseMap = {}, --get strings back from unique id
  }
  local stack = {}
  for k in pairs(target) do
    table.insert(state.__inverseMap, k)
    table.insert(stack,#state.__inverseMap)
    state.__forwardMap[k] = #state.__inverseMap
  end
  return timer:Do("GetProblemConstants",timer,state,stack,{})
end

function taskMap.GetProblemConstants(timer,state,queue,visited)
  local graph,masterGraph = state.graph, state.MasterGraph
  for i = 1,40 do
    if queue:len() == 0 then
      return timer:Do("PreSolve",timer,state)
    end
    local node = queue:pop()
    node.visited = true
    if node.type == "source" then
      state.source[node.id] = node.cost or 1
    end
    for edgeid, edge in pairs(masterGraph.nodes[node.id].inflow) do
      AddMapping(state,edgeid)
      table.insert(state.recipes, edge)
      for nodeid, outflowNode in pairs(edge.outflow) do
        if not graph.nodes[nodeid] then
          AddMapping(state,nodeid)
          graph:AddNode(outflowNode) -- wrong direction, only here to ensure the edge can be added
        end
      end
      for nodeid, inflowNode in pairs (edge.inflow) do
        if not graph.nodes[nodeid] then
          local newNode = graph:AddNode(inflowNode)
          if not node.visited then
            queue:push(node)
          end
          AddMapping(state,nodeid)
          queue:push(newNode)
        end
      end
      graph:AddEdge(edge)
    end
  end
  return timer:Do("GetProblemConstants",timer,state,stack,visited)
end

function taskMap.RegularizeProblem(timer,state)
  return timer:Do("LPSolve",timer,state)
end

function taskMap.LPSolve(timer,state)
  for i = 1,40 do
  end
  return timer:Do("LPSolve",timer,state)
end



return Chain
