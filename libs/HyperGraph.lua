-- Implementation of HyperGraphs in lua

-- modules
local logger = require "misc.logger"
local inspect = require "inspect"
require "util"

-- main object
local HyperGraph = {}

-- metatables
local HyperGraphMt = { __index = HyperGraph}
local weakMt = {__mode = "kv"}

-- helpers
local validData = {
  node = {
    id = "string",
    inflow = "weaktable",
    outflow = "weaktable",
  },
  edge = {
    id = "string",
    category = "string",
    hidden = "boolean",
    energy = "number",
    products = "table",
    ingredients = "table",
    inflow = "weaktable",
    outflow = "weaktable",
  },
}

local function Validate(data, format)
  if type(data) ~= "table" then return end
  data = table.deepcopy(data)
  for field, dataType in pairs(validData[format]) do
    local fieldType = type(data[field])
    if fieldType ~= dataType then
      if dataType == "weaktable"  then
        data[field] = setmetatable({}, weakMt)
      end
    end
  end
  data.valid = false
  return data
end

-- pre-runtime scripts
function HyperGraph:Init()
  global.fullGraph, global.forceGraphs = self:New(), {}
  return global.fullgraph, global.forcegraphs
end

function HyperGraph:Load()
  for _,graph in pairs(global.forcegraphs) do
    self.setmetatables(graph)
  end
  return HyperGraph.setmetatables(global.fullgraph), global.forcegraphs
end

-- methods
function HyperGraph.setmetatables(hgraph)
  setmetatable(hgraph, HyperGraphMt)
  for _, node in pairs(hgraph.nodes) do
    setmetatable(node.inflow, weakMt)
    setmetatable(node.outflow, weakMt)
  end
  for _, edge in pairs(hgraph.edges) do
    setmetatable(edge.inflow, weakMt)
    setmetatable(edge.outflow, weakMt)
  end
  for _, chain in pairs(hgraph.chains) do
    Chain.setmetatables(chain)
  end
  return hgraph
end

function HyperGraph:New()
  local hgraph = HyperGraph.setmetatables({
    nodes = {},
    edges = {},
    chains = {},
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
        node.outflow[edgeid] = edge
        node.inflow[edgeid] = edge
        edge.inflow[nodeid] = node
        edge.outflow[nodeid] = node
      else
        logger:log(1, "error", "HyperGraph.lua: Attempt to add an edge with an invalid catalyst.",3)
      end
    end
  end
  for nodeid in pairs(edge.ingredients) do
    local node = self.nodes[nodeid]
    if node then
      node.outflow[edgeid] = edge
      edge.inflow[nodeid] = node
    else
      logger:log(1, "error", "HyperGraph.lua: Attempt to add an Edge with an invalid input.",3)
    end
  end
  for nodeid in pairs(edge.products) do
    local node = self.nodes[nodeid]
    if node then
      node.inflow[edgeid] = edge
      edge.outflow[nodeid] = node
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
  return HyperGraph.setmetatables(table.deepcopy(self))
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