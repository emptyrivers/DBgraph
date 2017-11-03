--[[
Implementation of HyperGraphs, in the context of the Factorio recipe system.
requires PocketWatch.lua to function.


Usage:

Each Graph consists of nodes and edges, which are housed in the .nodes and .edges fields.
Each node and edge has 2 weak tables associated with it, indicating the incident parents and children.

In the context of factorio, nodes are items, and edges are recipes.

local hgraph = HyperGraph:New(nodes, edges)
Creates a new hypergraph object, initialized with the specified nodes and edges

hgraph:AddNode(data)
Adds a new node. Checks for validity of the node data

hgraph:AddEdge(data)
Adds a new edge. Checks for validity of the edge data. The inflow and outflow edges must exist, or the edge will not be added.

hgraph:RemoveNode(id)
Removes the node, if it exists. Also removes any edge that has the node as an endpoint.

hgraph:RemoveEdge(id)
Removes the edge, if it exists. Also removes the edge from inflow and outflow data of the nodes it connected.

hgraph:CLone()
returns a deep copy of the hgraph. The two are entirely separate objects; mutating one object will never mutate the other.
**NOTE** this only holds for data about the graph itself. Any mutable user data will not be cloned.


Written by Emptyrivers. Contact: Rivers#8800, or user emptyrivers
All rights relinquished. (see ./License.md for details).
--]]

--[[
local PocketWatch = require "modules.PocketWatch"TODO: figure out if i actually need this
if not PocketWatch then return end
--]]

local HyperGraph = {}

HyperGraph.MT = {
  __index = HyperGraph
}


function HyperGraph:New(nodes, edges)
  local hgraph = setmetatable({
    nodes = {},
    edges = {},
  }, HyperGraph.MT)
  if nodes then
    for _, node in pairs(nodes) do
      hgraph:AddNode(node)
    end
  end
  if edges then
    for _, edge in pairs(edges) do
      hgraph:AddEdge(edge)
    end
  end
  return hgraph
end

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

local weakMT = {__mode = "kv"}

local function Validate(data, format)
  if type(data) ~= "table" then return end
  data = table.deepcopy(data)
  for field, dataType in pairs(validData[format]) do
    local fieldType = type(data[field])
    if fieldType ~= dataType then
      if dataType == "weaktable" and fieldType == "table" then
        setmetatable(data[field], weakMT)
      else
        data[field] = setmetatable({}, weakMT)
      end
    end
  end
  data.valid = false
  return data
end

function HyperGraph:AddNode(data)
  local node = Validate(data, "node")
  if node then
    self.nodes[node.id] = node
  else
    log "HyperGraph.lua - Warning! Invalid data format on AddNode."
    return
  end
  node.valid = true
end

function HyperGraph:AddEdge(data)
  local edge = Validate(data, "edge")
  if edge then
    local edgeid = edge.id
    self.edges[edgeid] = edge
    for nodeid in pairs(edge.ingredients) do
      local node = self.nodes[nodeid]
      if node then
        node.outflow[edgeid] = edge
        edge.inflow[nodeid] = node
      else
        log "HyperGraph.lua - Warning! Attempt to add an Edge with an invalid input."
        return
      end
    end
    for nodeid in pairs(edge.products) do
      local node = self.nodes[nodeid]
      if node then
        node.inflow[edgeid] = edge
        edge.outflow[nodeid] = node
      else
        log "HyperGraph.lua - Warning! Attempt to add an Edge with an invalid output."
        return
      end
    end
  else
    log "HyperGraph.lua - Warning! Invalid data format on AddEdge."
    return
  end
  edge.valid = true
end

function HyperGraph:RemoveNode(nodeid)
  if self.nodes[nodeid] then
    self.nodes[nodeid].valid = false
    self.nodes[nodeid] = nil
    for edgeid, edge in pairs(self.edges) do
      if edge.inflow[nodeid] or edge.outflow[nodeid] then
        self:RemoveEdge(nodeid)
      end
    end
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

function HyperGraph.setmetatables(hgraph)
  setmetatable(hgraph, HyperGraph.MT)
  for _, node in pairs(hgraph.nodes) do
    setmetatable(node, weakMT)
  end
  for _, edge in pairs(hgraph.edges) do
    setmetatable(edge, weakMT)
  end
end

return HyperGraph
