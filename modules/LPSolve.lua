

require "util"
local taskMap = require("modules.PocketWatch").taskMap

local Matrix = {}
local matrixMt = {
  __index = Matrix,
  __add = function()end
}



function taskMap.SolveChain(timer,target,guiElement)
  -- 
  local state = {
    element = guiElement,
    target = target,
    recipes = {},
    source = {},
    __forwardMap = {}, --maps strings to unique id for this problem
    __inverseMap = {}, --get strings back from unique id
  }
  local stack = {}
  for k in pairs(target) do
    table.insert(state.__inverseMap, k)
    table.insert(stack,#state.__inverseMap)
    state.__forwardMap[k] = #state.__inverseMap
  end
  return timer:Do("GetProblemConstants",timer,state,stack,{})
end

function taskMap.GetProblemConstants(timer,state,stack,visited)
  for i = 1,40 do
    if #stack == 0 then
      return timer:Do("RegularizeProblem",timer,state)
    end
  end
  return timer:Do("GetProblemConstants",timer,state,stack,visited)
end

function taskMap.RegularizeProblem(timer,state)
  return timer:Do("LPSolve",timer,state)
end

function taskMap.LPSolve(timer,state)
  for i = 1,40 do
  end
  return timer:Do("LPSolve",timer,state)
end



return Chain
