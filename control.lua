local HyperGraph = require "modules.HyperGraph"
local PocketWatch = require "modules.PocketWatch"
local mod_gui = require "mod-gui"
local timer, fullGraph, techTree, productionChain, loaded
local events = defines.events


--define helper functions
local function buildTechTree(techTree)
  --we only care about techs that unlock recipes...
  local stack = {}
  for name, tech in pairs(game.technology_prototypes) do
    for _, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" then
        if not techTree[name] then
          techTree[name] = {
            unlocks = {effect.recipe},
            prereq  = tech.prerequisites,
            name = name,
          }
          techTree._inverted[effect.recipe] = name
          table.insert(stack, techTree[name])
        else
          techTree._inverted[effect.recipe] = techTree[name]
          table.insert(techTree[name].unlocks,effect.recipe)
        end
      end
    end
  end
  --...and their prerequisites!
  while #stack > 0 do
    local tech = table.remove(stack)
    for name, tech in pairs(tech.prereq) do
      if not techTree[name] then
        techTree[name] = {
          prereq = tech.prerequisites,
          name = name
        }
      end
    end
  end
end


local function explore(graph, force)
  for name, prototype in pairs(game.item_prototypes) do
    if prototype.valid then
      graph:AddNode({id = name, type = "item"})
    end
  end
  for name, prototype in pairs(game.fluid_prototypes) do
    if prototype.valid then
      graph:AddNode({id = name, type = "fluid"})
    end
  end
  local recipes = force and force.recipes or game.recipe_prototypes
  for name, recipe in pairs(recipes) do
    local data = {
      id = name,
      category = recipe.category,
      enabled = recipe.enabled,
      energy = recipe.energy,
      ingredients = {},
      products = {},
      inflow = {},
      outflow = {},
    }
    data.prereq = techTree._inverted[name]
    for _, ingredient in ipairs(recipe.ingredients) do
      data.ingredients[ingredient.name] = ingredient
    end
    for _, product in ipairs(recipe.products) do
      data.products[product.name] = product
    end
    graph:AddEdge(data)
  end
end

local function rebuild(graph, force)
  --TODO: Implementation
  --should schedule re-exploration of the graph, since it's very difficult to tell what's changed
end

local function updatePaths(graph, recipe)
  --TODO: Implementation
  --Schedules an update to paths - needs algorithm to update paths implemented first :)
end

local function createGUI(event)
  local flow = mod_gui.get_button_flow(game.players[event.player_index])
  local frame = flow.add{
    type = "frame",
    name = "ProductionChainMenuButtonFrame",
    direction = "horizontal"
  }
  frame.add{
    type = "button",
    name = "ProductionChainMenuButton",

  }
  game.print"successfully created GUI"
end

do
  script.on_init(function()
    global.timer = PocketWatch:New()
    global.fullGraph = HyperGraph:New()
    global.forceGraphs = {}
    global.techTree = { _inverted = {}}
    timer = global.timer
    timer.id = "Primary Timer"
    fullGraph = global.fullGraph
    techTree = global.techTree
    buildTechTree(techTree)
    explore(fullGraph)
  end)

  script.on_load(function()
    fullGraph = HyperGraph.setmetatables(global.fullGraph)
    timer = PocketWatch.setmetatables(global.timer)
    for _, graph in pairs(global.forceGraphs) do
      HyperGraph.setmetatables(graph)
    end
    script.on_event(events.on_tick, timer.continueWork)
  end)


  script.on_configuration_changed(function(event)
    rebuild(fullGraph)
    for force, graph in pairs(productionChain.forceGraphs) do
      rebuild(graph, force)
    end
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

  script.on_event(events.on_player_created,  createGUI)

  script.on_event({
    events.on_force_created,
    events.on_forces_merging,
    --events.on_player_changed_force,
  }, function(event)
    if event.name == events.on_force_created then
      productionChain.forceGraphs[event.force.name] = HyperGraph:New()
      explore(productionChain.forceGraphs[event.force.name])
    elseif event.name == events.on_forces_merging then
      destroy(event.force.name)
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
  end)
end
