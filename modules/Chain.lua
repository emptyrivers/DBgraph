require "util"
local Chain = {}
local chainMt = { __index = Chain }
local btest= bit32.btest
--[[
A Chain is an object, which represents a somewhat idealized factory:
* The inflow field is an array of {item, amount}, representing the items fed into the factory. `item` is a string that refers to a node from the parent graph
* The outflow represents items which are leaving the factory. Structure is {item, amount, intended}, where `intended` is a tristate.
  True if intended, False if a byproduct, nil if unknown/don't care.
* The sideflow field represents items flowing between branches of the factory.
  Structure is {item, amount, Sidechain, index,}, where SideChain is a Chain object,
  and index is the point of insertion/extraction (negative if leaving this factory, positive if entering)
* Each link represents a group of machines, all of which are performing a single recipe.
  Each link is itself a chain object, and there can be several types:
    if type == -1, then chain is a single recipe (and #links == 0). Inflow travels directly to outflow.
    else, type is considered a bitfield:
    0x1 = compound (at least one of the links is a chain of type >= 0)
    0x2 = cyclic (at least one of the ingredients is also a product (there's a sense of "self-sideflow")
    0x4 = branching (at least one of the byproducts is a chain)
--]]

function Chain:New(graph) -- where data is an edge in the chain's parent graph
  local chain = setmetatable(
  {
    links = {},
    inflow = {},
    outflow = {},
    sideflow = {},
    parent = graph,
    type = -1,
  }, chainMt)
end



function Chain.setmetatables(chain)
  for _, link in pairs(chain.links) do
    Chain.setmetatables(link)
  end
  for _, byproduct in pairs(chain.sideflow) do
    Chain.setmetatables(byproduct[3])
  end
  return setmetatable(chain, chainMt)
end



return Chain
