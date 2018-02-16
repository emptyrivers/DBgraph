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



return snippets