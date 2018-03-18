-- Implementation of HyperGraphs in lua

-- modules
local logger = require "misc.logger"
local inspect = require "inspect"
local snippets = require "misc.snippets"

require "util"

-- main object
local HyperGraph = {}

-- metatables
local HyperGraphMt = { __index = HyperGraph}
HyperGraph.mt = HyperGraphMt
-- helpers
local validData = {
  node = {
    id = "string",
  },
  edge = {
    id = "string",
    category = "string",
    products = "table",
    ingredients = "table",
  },
}

local function Validate(data, format)
  if type(data) ~= "table" then return end
  data = snippets.rawcopy(data)
  for field, dataType in pairs(validData[format]) do
    local fieldType = type(data[field])
    if fieldType ~= dataType then
      return logger:log(1,"error","Invalid data format "..type(data[field]).." on field:"..field,3)
    end
  end
  data.inflow = {}
  data.outflow = {}
  data.valid = false
  return data
end


-- pre-runtime scripts
function HyperGraph:Init()
  global.fullGraph, global.forceGraphs = BuildGraph(HyperGraph:New()), {}
  _G.forceGraphs = {}
  self.setmetatable(snippets.BuildLocalCopy(global.fullGraph))
  return global.fullgraph, global.forcegraphs
end

function HyperGraph:Load()
  _G.forceGraphs = {}
  for forceName,graph in pairs(global.forceGraphs) do
    self.setmetatable(snippets.BuildLocalCopy(graph, forceName))
  end
  self.setmetatable(snippets.BuildLocalCopy(global.fullGraph))
end

function HyperGraph:OnConfigurationChanged()
  BuildGraph(global.fullGraph, nil, true)
  self.setmetatable(snippets.BuildLocalCopy(global.fullGraph))
  for forceName,graph in pairs(global.forceGraphs) do
    BuildGraph(graph,forceName,true)
    self.setmetatable(snippets.BuildLocalCopy(graph, forceName))
  end
end

-- methods
function HyperGraph.setmetatable(hgraph)
  return setmetatable(hgraph, HyperGraphMt)
end

function HyperGraph:New()
  local hgraph = HyperGraph.setmetatable({
    nodes = {},
    edges = {},
    type = "HyperGraph",
  })
  return hgraph
end

function HyperGraph:AddNode(data)
  local node = Validate(data, "node")
  if not node then
    logger:log(1, 'error', "HyperGraph.lua: Invalid data format on AddNode.",3)
  end
  self.nodes[node.id] = node
  node.valid = true
  return node
end

function HyperGraph:AddEdge(data)
  local edge = Validate(data, "edge")
  if not edge then
    logger:log(1, 'error', "HyperGraph.lua: Invalid data format on AddEdge.",3)
  end
  local edgeid = edge.id
  if edge.catalysts then
    for nodeid in pairs(edge.catalysts) do
      local node = self.nodes[nodeid]
      if node then
        node.outflow[edgeid] = false
        node.inflow[edgeid] = false
        edge.inflow[nodeid] = false
        edge.outflow[nodeid] = false
      else
        logger:log(1, "error", "HyperGraph.lua: Attempt to add an edge with an invalid catalyst.",3)
      end
    end
  end
  for nodeid in pairs(edge.ingredients) do
    local node = self.nodes[nodeid]
    if node then
      node.outflow[edgeid] = false
      edge.inflow[nodeid] = false
    else
      logger:log(1, "error", "HyperGraph.lua: Attempt to add an Edge with an invalid input.",3)
    end
  end
  for nodeid in pairs(edge.products) do
    local node = self.nodes[nodeid]
    if node then
      node.inflow[edgeid] = false
      edge.outflow[nodeid] = false
    else
      logger:log(1, 'error', "HyperGraph.lua: Attempt to add an Edge with an invalid output.",3)
    end
  end
  self.edges[edgeid] = edge
  edge.valid = true
  return edge
end

function HyperGraph:RemoveNode(nodeid)
  if self.nodes[nodeid] then
    self.nodes[nodeid].valid = false
    for edgeid,edge in pairs(self.nodes[nodeid].inflow) do
      if edge.valid then self:RemoveEdge(edgeid) end
    end
    for edgeid,edge in pairs(self.nodes[nodeid].outflow) do
      if edge.valid then self:RemoveEdge(edgeid) end
    end
    self.nodes[nodeid] = nil
  end
end

function HyperGraph:RemoveEdge(edgeid)
  if self.edges[edgeid] then
    self.edges[edgeid].valid = false
    self.edges[edgeid] = nil
  end
end

function HyperGraph:Clone()
  return HyperGraph.setmetatable(table.deepcopy(self))
end

function HyperGraph:Dump(method, playerID)
  local graph = self:Clone()
  for _, node in pairs(graph.nodes) do
    node.inflow = nil
    node.outflow = nil
  end
  for _, edge in pairs(graph.edges) do
    edge.inflow = nil
    edge.outflow = nil
  end
  local toLog = ([[
HyperGraph Dump at: %d
%s]]):format(game and game.tick or 0, inspect(graph))
  return toLog
end

return HyperGraph
