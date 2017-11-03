local HyperGraph = require "modules.HyperGraph"
local PocketWatch = require "modules.PocketWatch"

local timer, fullGraph, productionChain
local events = defines.events

--define helper functions
function explore(graph, isMaster)
  --iterate through prototypes and add, remove, and edit our model such that it is accurate
  --first, add item, fluid, recipes to graph
end

function update(graph, isMaster)
  --TODO: Implementation
end

function updatePaths(graph, recipe)
  --TODO: Implementation
end






--register events
do
  script.on_init(function()
    global.productionChain = {
      timer = PocketWatch:New(),
      fullGraph = HyperGraph:New(),
      forceGraphs = {},
    }
    productionChain = global.productionChain
    timer = productionChain.timer
    fullGraph = productionChain.fullGraph
    explore(fullgraph, true)
  end)
  script.on_load(function()
    productionChain = global.productionChain
    fullGraph = HyperGraph.setmetatables(productionChain.fullGraph)
    timer = PocketWatch.setmetatables(productionChain.timer)
    for _, graph in pairs(productionChain.forceGraphs) do
      HyperGraph.setmetatables(graph)
    end
  end)
  script.on_configuration_changed(function(event)
    update(fullGraph,true)
    for _, graph in pairs(productionChain.forceGraphs) do
      update(graph)
    end
  end)
  script.on_event(events.on_tick, function(event)
    timer:DoTasks()
  end)
  script.on_event(events.on_research_finished, function(event)
    local research = event.research
    local graph = productionChain.forceGraphs[research.force.name]
    for _, effect in ipairs(research.effects) do
      if effect.type == "unlock-recipe" then
        updatePaths(graph, research.force.recipes[effect.recipe])
      end
    end
  end)
  script.on_event(events.on_player_created,  function(event)
    --TODO: this handler needs to build the GUI that the player sees. Will perhaps outsource to a gui module
  end)
  script.on_event({
    events.on_force_created,
    events.on_forces_merging,
    --events.on_player_changed_force,
  }, function(event)
    if event.name == "on_force_created" then
      local graph = productionChain.forceGraphs[event.force.name] = HyperGraph:New()
      explore(graph)
    elseif event.name == "on_forces_merging" then
      productionChain.forceGraphs[event.force.name] = nil
    --else
      --not sure if i really need to do anything here. responder should be able to understand which force the player is part of.
    end
  end)
  script.on_event({
    events.on_gui_checked_state_changed,
    events.on_gui_clicked,
    events.on_gui_elem_changed,
    events.on_gui_selection_state_changed,
    events.on_gui_text_changed,
  }, function(event)
    --TODO: this handler responds to user interaction. Will perhaps be outsourced to a gui module
  end)
end
