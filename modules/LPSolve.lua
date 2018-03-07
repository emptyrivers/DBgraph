
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
  table.insert(state.__forwardMap, toMap)
  state.__inverseMap[#state.__forwardMap] = toMap
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
          if not newNode.visited then
            queue:push(newNode)
          end
          AddMapping(state,nodeid)
        end
      end
      graph:AddEdge(edge)
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
