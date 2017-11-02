local HyperGraph = require "modules.HyperGraph"
local PocketWatch = require "modules.PocketWatch"

local timer, fullGraph

local function explore(graph)

end

local function constructGUI()

end

script.on_init(function()
  global.productionChain = {
    timer = PocketWatch:New(),
    fullGraph = HyperGraph:New(),
    forceGraphs = {},
  }
  timer = global.productionChain.timer
  fullGraph = global.productionChain.fullGraph
  timer:Do(false, explore, fullGraph)
end)

script.on_load(function()
  fullGraph = HyperGraph.setmetatables(global.productionChain.fullGraph)
  timer = PocketWatch.setmetatables(global.productionChain.timer)
  for _, graph in pairs(global.productionChain.forceGraphs) do
    HyperGraph.setmetatables(graph)
  end
end)

script.on_configuration_changed(function(data)
  timer:Do(false, explore, fullGraph)
end)

script.on_event(defines.events.on_tick, function()
  timer:DoTasks()
end)
