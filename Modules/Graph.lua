--[[
local Node = {}
local nodeMT = {
  __index = Node,
  __metatable = true,
}

function Node:New()
  
end

local Edge = {}
local edgeMT = {
  __index = Edge,
  __metatable = true,
}
--]]

local Graph = {}
local graphMT = {
  __index = Graph,
  __metatable = true,
}

function Graph:AddNode(data)
  self.nodes[data.id] = Node:New(data(
end

function Graph:AddEdge(data startNode, endNode)
  if self.nodes[startNode] and self.nodes[endNode] then
    self.edges[data.id] = Edge:New(data)
    data.start = startNode
    data.end = endNode
  else
    log "Graph.lua - warning! Attempt to add an edge to nodes that don't exist."
  end
end



function Graph:RemoveEdge(id)
  self.edges[id] = nil
end

function Graph:RemoveNode(id)
  for edge, data in pairs(self.edges) do
    if id == data.start or id == data.end then
      self.edges[edge] = nil
    end
  end
  self.nodes[id] = nil
end 

function Graph:New()
  local graph = setmetatable(
    {
      nodes = {}
      edges = {}
    }, 
    graphMT
  )
  return graph
end