
-- customized implementation of Revised Simplex method

require "util"
local taskMap = require("modules.PocketWatch").taskMap
local matrix  = require "modules.matrix" 


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

function AddMapping(state, toMap)
  if state.__inverseMap[toMap] then return end
  table.insert(state.__forwardMap, toMap)
  state.__inverseMap[toMap] = #state.__forwardMap
end

function taskMap.BeginProblem(timer,graph,target,guiElement)
  -- first, create problem state which will persist until the problem is solved
  local state = {
    graph = HyperGraph:New(),
    masterGraph = graph,
    element = guiElement,
    target = target,
    recipes = {},
    source = {},
    __forwardMap = {}, --maps strings to unique id for this problem
    __inverseMap = {}, --get strings back from unique id
  }
  local queue = NewQueue()
  for k in pairs(target) do
    local node = graph.nodes[k]
    queue:push(node)
    state.graph:AddNode(node)
    AddMapping(state,k)
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
      table.insert(state.recipes, edge)
      for nodeid, outflowNode in pairs(edge.outflow) do
        if not graph.nodes[nodeid] then
          graph:AddNode(outflowNode) -- wrong direction, only here to ensure the edge can be added
          AddMapping(state,nodeid)
        end
      end
      for nodeid, inflowNode in pairs (edge.inflow) do
        local newNode = graph.nodes[nodeid] or graph:AddNode(inflowNode)
        AddMapping(state,node.id)
        if not newNode.visited then
          queue:push(newNode)
        end
      end
      graph:AddEdge(edge)
      AddMapping(state,edgeid)
    end
  end
  return timer:Do("GetProblemConstants",timer,state,stack,visited)
end


function taskMap.PreSolve(timer,state) -- optional? who knows
  do return logger:log(1,'file', {filePath = "LP_log", data = state.graph:Dump(), for_player = 1}) end
  return timer:Do("LPSolve",timer,state)
end
function taskMap.LPSolve(timer,state)
  for i = 1,40 do
  end
  return timer:Do("LPSolve",timer,state)
end
function taskMap.PostSolve(timer,state)
  for i = 1,40 do
    if isDone then
      return state.element.updateDisplay(state)
    end
  end
  return timer:Do("PostSolve",timer,state)
end


return {}
