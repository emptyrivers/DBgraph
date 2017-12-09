require "util"
--local Link = require "modules.Link"
local Chain = {}
local chainMt = { __index = Chain }

-- type is a bitfield: 
-- -1 (special!) chain is a single recipe
-- 1 = compound (at least one of the links is a chain with length > 1) 
-- 2 = cyclic (at least one of the ingredients is also a product
-- 4 = branching (at least one of the byproducts is a chain)

function Chain:New(data)
  if data then
    local chain = setmetatable({
      type = 0,
      links = {table.deepcopy(data))
      ingredients = {}
      products = {}
      byproducts = {}
   }, chaimMt) 
    chain.ingredients = table.deepcopy(chain.links[1].ingredients)
    chain.products = table.deepcopy(chain.links[1].products)  
  else
    return setmetatable({
      type = 0,
      links = {},
      ingredients = {},
      byproducts = {},
      products = {},
    }, chainMt)
  end
end

function Chain:Evaluate(input, isSubCall)
  local result = input and table.deepcopy(input) or table.deepcopy(self.ingredients)
  for _, link in ipairs(self.links) do
    if link.type == -1 then
      local bottleNeck, bottleNeckAmount = "null", math.huge
        for ingredient, amount in pairs(link.ingredients) do
          if not result[ingredient] or result[ingredient] == 0 then
            bottleNeck, bottleNeckAmount = ingredient, 0
            break
          elseif result[ingredient] < bottleNeckAmount then
            bottleNeck, bottleNeckAmount = ingredient, result[ingredient]
            
end

function Chain:Append(toAppend, isBegin)
  if isBegin then
    
  else
    table.insert(self.links, toAppend)
    
  end
  return self
end

function Chain:Join(toJoin, atByproduct)
  local branchPoint = self.byproducts[atByproduct]
  if branchPoint then 
    
  else
    error( "ProductionChain: Attempt to join at a non-existent branch point.", 2 )
  end
  return self
end
