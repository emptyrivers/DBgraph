local snippets = {}


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

function snippets.NewQueue()
  return {
    first = 0,
    last  = 0,
    pop  = function(self) --technically unsafe, but you'd have to try really hard to saturate this queue
      local val
      repeat -- allows us to take something out of the middle of the queue, but defer the cost of updating the queue until we pop it
        if self.first == self.last then return end
        self.first = self.first + 1
        val = self[self.first]
      until self.queued[val]
      self.queued[val] = nil
      self[self.first] = nil
      self.first = self.first + 1
      return val
    end,
    push = function(self, toPush)
      if self.queued[toPush]  then return end
      self[self.last] = toPush
      self.last = self.last + 1
      self.queued[toPush] = self.last
    end,
    len = function(self)
      return self.last - self.first
    end,
    queued = {},
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