

for k, v in pairs(defines.events) do
  _G[k] = v -- because fuck writing defines.events.on_whatever_event every damn time!
end

-- modules
local lib = require "lib"
local widgets = require "modules.widgets"
local util = require "util"
inspect  = require "inspect"
snippets = require "misc.snippets"
logger   = require "misc.logger"
require "modules.LPSolve"
require "modules.DataStructures"


local function logCommand(event)
  for _, node in pairs(global.fullGraph.nodes) do
    node.inflow = nil
    node.outflow = nil
  end
  for _, edge in pairs(global.fullGraph.nodes) do
    edge.inflow = nil
    edge.outflow = nil
  end
end

local function logCommand()
  game.write_file("fullgraph.log",fullGraph:Dump())
  game.print('done')
end
-- script handlers
script.on_init(function()
  global.techTree = BuildTechTree()
  _G.techTree = snippets.rawcopy(global.techTree)
  for _, tech in pairs(techTree) do
    if tech.prereq then
      for name in pairs(tech.prereq) do
        tech.prereq[name] = TechTree[name]
      end
    end
  end
  lib:Init()
  timers = global.timers
  lib.PocketWatch:New("main")
  commands.add_command("pc_dump",{"","Dumps info requested into script_output. Primarily for dev use."},logCommand)
end)

script.on_load(function()
  timers = global.timers
  for _, timer in pairs(timers) do
    if timer.working then
      script.on_event(on_tick, timer.continueWork)
      break
    end
  end
  _G.techTree = snippets.rawcopy(global.techTree)
  for _, tech in pairs(techTree) do
    if tech.prereq then
      for name in pairs(tech.prereq) do
        tech.prereq[name] = TechTree[name]
      end
    end
  end
  lib:Load()
  commands.add_command("pc_dump",{"","Dumps info requested into script_output. Primarily for dev use."},logCommand)
end)

script.on_configuration_changed(function(event)
  global.techTree = BuildTechTree()
  _G.techTree = snippets.rawcopy(global.techTree)
  for _, tech in pairs(TechTree) do
    for name in pairs(tech.prereq) do
      tech.prereq[name] = TechTree[name]
    end
  end
  lib:OnConfigurationChanged()
end)

--[[ script.on_event(on_research_finished, function(event)
  local unlockedRecipes = techTree[event.research.name] and techTree[event.research.name].unlocks
  local graph =  forceGraphs[event.research.force.name]
  if unlockedRecipes and graph then
    timer:Do('updatePaths', graph, unlockedRecipes)
  end
end) ]]

script.on_event(on_player_changed_force, function(event)
  local playerID = event.player_index
  local playerForce = game.players[playerID].force.name
  if not forceGraphs[playerForce] then
    --forceGraphs[playerForce] = lib.HyperGraph:New()
    --timer:Do('explore', forceGraphs[playerForce], playerForce)
  end
end)

script.on_event(on_player_created, function(event)
  local playermodel = lib.GUI:New(event.player_index)
  playermodel.top:Add(widgets.Top_Button)
  --[[ logger:log(1,'file',{filePath = "GUI_Log",data = playermodel:Dump(), for_player = event.player_index})
  local playerForce = game.players[event.player_index].force.name
  if not forceGraphs[playerForce] then
    forceGraphs[playerForce] = lib.HyperGraph:New()
    timer:Do('explore', forceGraphs[playerForce], playerForce)
    end  
    logger:log(1,'file',{filePath = "Graph_Log",data = fullGraph:Dump(), for_player = event.player_index}) ]]
end)

script.on_event(on_player_removed, function(event)
  lib.GUI:Delete(event.player_index)
end)
--[[ 
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
) ]]