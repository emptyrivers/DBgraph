

for k, v in pairs(defines.events) do
  _G[k] = v -- because fuck writing defines.events.on_whatever_event every damn time!
end


-- modules
local lib = require "lib"
local widgets = require "modules.widgets"
local snippets = require "misc.snippets"
local logger   = require "misc.logger"
local inspect  = require "inspect"
require "modules.LPSolve"
require "modules.DataStructures"

-- upvalues
local taskMap     = lib.PocketWatch.taskMap
local snippets    = snippets
local rational = lib.rational
local rationalize = rational.rationalize

-- upvalues to be assigned in init/load
local timers, fullGraph, techTree, forceGraphs, models


-- script handlers
script.on_init(function()
  lib:Init()
  fullGraph,        forceGraphs,        timers,        models,        techTree =
  global.fullGraph, global.forceGraphs, global.timers, global.models
  timer = lib.PocketWatch:New('main')
  global.techTree = timers.main:Do("buildTechTree", timers.main, {})
  techTree = global.techTree
  timers.main:Do("explore",fullGraph)
  commands.add_command("pc","test",function() game.print("Hello, World!")end)
end)

script.on_load(function()
  lib:OnLoad()
  fullGraph,        forceGraphs,        timers,        models,        techTree =
  global.fullGraph, global.forceGraphs, global.timers, global.models, global.techTree
  for _, timer in pairs(timers) do
    if timer.working then
      script.on_event(on_tick, timer.continueWork)
      break
    end
  end
  commands.add_command("pc","test",function() game.print("Hello, World!")end)
end)

script.on_configuration_changed(function(event)
  lib:OnConfigurationChanged()
  global.techTree = timer:Do("buildTechTree")
  timer:Do("explore", fullGraph, nil, true)
  for force, graph in pairs(global.forceGraphs) do
    timer:Do("explore", graph, force, true)
  end
end)

script.on_event(on_research_finished, function(event)
  local unlockedRecipes = techTree[event.research.name] and techTree[event.research.name].unlocks
  local graph =  forceGraphs[event.research.force.name]
  if unlockedRecipes and graph then
    timer:Do('updatePaths', graph, unlockedRecipes)
  end
end)

script.on_event(on_player_changed_force, function(event)
  local playerID = event.player_index
  local playerForce = game.players[playerID].force.name
  if not forceGraphs[playerForce] then
    forceGraphs[playerForce] = lib.HyperGraph:New()
    timer:Do('explore', forceGraphs[playerForce], playerForce)
  end
end)

script.on_event(on_player_created, function(event)
  local playermodel = lib.GUI:New(event.player_index)
  playermodel.top:Add(widgets.Top_Button)
  logger:log(1,'file',{filePath = "GUI_Log",data = playermodel:Dump(), for_player = event.player_index})
  local playerForce = game.players[event.player_index].force.name
  if not forceGraphs[playerForce] then
    forceGraphs[playerForce] = lib.HyperGraph:New()
    timer:Do('explore', forceGraphs[playerForce], playerForce)
    end  
    logger:log(1,'file',{filePath = "Graph_Log",data = fullGraph:Dump(), for_player = event.player_index})
end)

script.on_event(on_player_removed, function(event)
  lib.GUI:Delete(event.player_index)
end)

script.on_event(on_forces_merging, function(event)
    forceGraphs[event.force.name] = nil
  end
)

remote.add_interface("rivers",
  {
    dump = function(...) logger:log(4,'file', {data = fullGraph:Dump(), filePath = "HG_Log", for_player = 1}, 1) end,
    count = function() 
      game.print('# of nodes: '..table_size(fullGraph.nodes)) 
      game.print('# of edges: ' .. table_size(fullGraph.edges)) 
      local e = 0
      for _,edge in pairs(fullGraph.edges) do
        e = e + (table_size(edge.inflow) + table_size(edge.outflow))^2
      end
      game.print('weight of edges: '..e)
    end
  }
)