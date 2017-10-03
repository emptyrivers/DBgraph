local DBGraph = {}
local graphMt = { __index = DBGraph}











function DBGraph:new()
  local graph = setmetatable({}, graphMt)
  return graph
end


return DBGraph