local HyperGraph = require "modules.HyperGraph"
local PocketWatch = require "modules.PocketWatch"

local timer, fullGraph
local events = defines.events
local function explore(graph, isMaster)
  --iterate through prototypes and add, remove, and edit our model such that it is accurate
  --first, add item, fluid, recipes to graph
end









local function init()
  global.productionChain = {
    timer = PocketWatch:New(),
    fullGraph = HyperGraph:New(),
    forceGraphs = {},
  }
  timer = global.productionChain.timer
  fullGraph = global.productionChain.fullGraph
  explore(fullgraph, true)
end
local function load()
  fullGraph = HyperGraph.setmetatables(global.productionChain.fullGraph)
  timer = PocketWatch.setmetatables(global.productionChain.timer)
  for _, graph in pairs(global.productionChain.forceGraphs) do
    HyperGraph.setmetatables(graph)
  end
end
local function reconfigure(event)
  update(fullGraph,true)
  for _, graph in pairs(global.productionChain.forceGraphs) do
    update(graph)
  end
end
local function continueWork(event)
  timer:DoTasks()
end
--TODO: the rest of these
local function updateForces(event)
end
local function constructGUI(event)
end
local function updateGraph(event)
end
local function respond()
end
script.on_init(init)
script.on_load(load)
script.on_configuration_changed(reconfigure)
script.on_event(events.on_tick,                   continueWork)
script.on_event(events.on_force_created,          updateForces)
script.on_event(events.on_forces_merging,         updateForces)
script.on_event(events.on_player_changed_force,   updateForces)
script.on_event(events.on_player_created,         constructGUI)
script.on_event(events.on_player_removed,         constructGUI)
script.on_event(events.on_research_finished,       updateGraph)
script.on_event(events.on_gui_checked_state_changed,   respond)
script.on_event(events.on_gui_clicked,                 respond)
script.on_event(events.on_gui_elem_changed,            respond)
script.on_event(events.on_gui_selection_state_changed, respond)
script.on_event(events.on_gui_text_changed,            respond)
