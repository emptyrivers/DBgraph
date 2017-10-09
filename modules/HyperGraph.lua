--[[
Implementation of HyperGraphs, in the context of the Factorio recipe system.
requires PocketWatch.lua to function.


Usage:

In this context, nodes are items, and edges are recipes.

local hgraph = HyperGraph:New(nodes, edges)
Creates a new hypergraph object, initialized with the specified nodes and edges.

hgraph:AddNode(data)
Adds a new node. Checks for validity of the node data

hgraph:AddEdge(data)
Adds a new edge. Checks for validity of the edge data. The inflow and outflow edges must exist, or the edge will not be added.

TODO:hgraph:RemoveNode(id)
Removes the node, if it exists. Also removes any edge that has the node as an endpoint.

TODO:hgraph:RemoveEdge(id)
Removes the edge, if it exists. Also removes the edge from inflow and outflow data of the nodes it connected.

TODO:hgraph:CLone()
returns a deep copy of the hgraph. The two are entirely separate objects; mutating one object will never mutate the other.
**NOTE** this only holds for data about the graph itself. Any mutable user data will not be cloned.

algorithms involving hypergraphs

Written by Emptyrivers. Contact: Rivers#8800, or user emptyrivers
All rights relinquished (see ./License.md for details).
--]]

local PocketWatch = require "modules.PocketWatch"
if not PocketWatch then return end


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
      hgraph:AddNode()
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
    inflow = "table"
    outflow = "table",
  },
  edge = {
    id = "string",
    inflow = "table",
    outflow = "table",
  },
}


local function Validate(data, format)
  if type(data) ~= "table" then return end
  for field, dataType in pairs(validData[format]) do
    if type(data[field]) ~= dataType then return end
  end
  return data
end

function HyperGraph:AddNode(data)
  data = Validate(data, "node")
  if not data then
    log "HyperGraph.lua - Warning! Invalid data format on AddNode."
    return
  else
    self.nodes[data.id] = data
  end
end

function HyperGraph:AddEdge(data)
  data = Validate(data, "edge")
  local id = data.id
  if not data then
    log "HyperGraph.lua - Warning! Invalid data format on AddEdge."
    return
  else
    for _, node in pairs(data.inflow) do
      if not self.nodes[node] then
        log "HyperGraph.lua - Warning! Attempt to add an outbound edge to a non-existent node."
        return
      end
    end
    for _, node in pairs(data.outflow) do
      if not self.nodes[node] then
        log "HyperGraph.lua - Warning! Attempt to add an inbound edge to a non-existent node."
        return
      end
    end
    self.edges[id] = data
    for _, node in pairs(data.inflow) do
      table.insert(self.nodes[node].outflow, id)
    end
    for _, node in pairs(data.outflow) do
      table.insert(self.nodes[node].inflow, id)
    end
  end
end


return HyperGraph
