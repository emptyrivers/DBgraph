local snippets = {}
local matrix = require("libs.matrix")

function snippets.wipe(t)
  for k in pairs(t) do 
    t[k] = nil 
  end
end

function snippets.trueFunc() 
  return true 
end

function snippets.redundancyType(prototype)
  local ret
  local name, category = prototype.name, prototype.category
  if name:find("^fill%-.*%-barrel$") then
    return "barrelFill"
  elseif name:find("^empty%-.*%-barrel$") then
    return "barrelEmpty"
  elseif prototype.products[1].name:find("void") then
    return "void"
  elseif name:find("%-barrel$") and name ~= "empty-barrel" then
    return true
  elseif name:find("GDIW%-[ABOI]R$") then
    return true
  elseif category:find("compress") or name:find("compress") or category:find("recycle")  then
    return true
  end
end

function snippets.BuildLocalCopy(graph,forceName)
  -- this must be a copy, since on_save doesn't exist and we need the saved version to not have the circular references
  local localGraph = snippets.rawcopy(graph)
  repairMetatables(localGraph)
  for pointid, connectionid in pairs{edges = "nodes",nodes = "edges"} do
    for _, point in pairs(localGraph[pointid]) do
      for _, flow in pairs{"inflow","outflow"} do
        for name in pairs(point[flow]) do
          point[flow][name]  = localGraph[connectionid][name]
        end
      end
    end
  end
  if forceName then
    _G.forceGraphs[forceName] = localGraph
  else
    _G.fullGraph = localGraph
  end
  return localGraph
end

function snippets.rawcopy(o, seen)
  seen = seen or {}
  if o == nil then return nil end
  if seen[o] then return seen[o] end


  local no = {}
  seen[o] = no
  --setmetatable(no, deepcopy(getmetatable(o), seen))

  for k, v in next, o, nil do
    k = (type(k) == 'table') and snippets.rawcopy(k, seen) or k
    v = (type(v) == 'table') and snippets.rawcopy(v, seen) or v
    no[k] = v
  end
  return no
end

function snippets.report(message, ...)
  local t = {message}
  for i, v in ipairs{...} do
    if type(v) == "table" then
      if getmetatable(v) and getmetatable(v).__tostring then
        table.insert(t, tostring(v))
      else
        table.insert(t, inspect(v))
      end
    else
      table.insert(t,tostring(v) or "nil")
    end
  end
  log(table.concat(t,"\n ------------------------------------------------\n")) 
end

function snippets.permute(A, P)
  local p, pt = matrix.new(#P), matrix.new(#P)
  for i, j in pairs(P) do
    p[j][i] = 1
    pt[i][j] = 1
  end
  return p * A * pt
end

function snippets.NewQueue()
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
function snippets.regVec(v)
  for i,e in v:elts() do
    if math.abs(e) <= 1e-14 then
      v[i] = 0
    end
  end
  return v
end
function snippets.regMatrix(m)
  for i,v in m:vects() do
    snippets.regvec(v)
  end
  return m
end

return snippets