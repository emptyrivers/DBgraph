local HyperGraph = require "modules.HyperGraph"
local PocketWatch = require "modules.PocketWatch"
local mod_gui = require "mod-gui"
local timer, fullGraph, techTree, forceGraphs
local events = defines.events
local taskMap = PocketWatch.taskMap

function taskMap.buildTechTree()
  --we only care about techs that unlock recipes...
  techTree = { _inverted = {} }
  local stack = {}
  for name, prototype in pairs(game.technology_prototypes) do
    for _, effect in pairs(prototype.effects) do
      if effect.type == "unlock-recipe" then
        if not techTree[name] then
          local data = {
            unlocks = {effect.recipe},
            prereq  = {},
            name = name,
            prototype = prototype,
          }
          techTree._inverted[effect.recipe] = data
          table.insert(stack, data)
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
    for name, prototype in pairs(tech.prototype.prerequisites) do
      if not techTree[name] then
        local data = {
          prereq = {},
          name = name,
          prototype = prototype,
        }
        tech.prereq[name] = data
        table.insert(stack, techTree[name])
      else
        tech.prereq[name] = techTree[name]
      end
    end
  end
end

function taskMap.explore(graph, forceName, shouldRebuild)
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
  local recipes = forceName and game.forces[forceName].recipes or game.recipe_prototypes
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
      data.ingredients[ingredient.name] = ingredient.amount
    end
    for _, product in ipairs(recipe.products) do
      data.products[product.name] = product.amount or 
        (product.probability * .5 * (product.amount_min + product.amount_max))
    end
    graph:AddEdge(data)
  end
  return timer:Do("createPaths", graph)
end

function taskMap.createPaths(graph)
end

function taskMap.updatePaths(graph, recipes)
end

function taskMap.createGUI(playerID)
  do return end
  local flow = mod_gui.get_button_flow(game.players[event.player_index])
  local frame = flow.add{
    type = "frame",
    name = "globalMenuButtonFrame",
    direction = "horizontal"
  }
  frame.add{
    type = "button",
    name = "globalMenuButton",
  }
  game.print"successfully created GUI"
end

do
  script.on_init(function()
    global.timer = PocketWatch:New()
    global.fullGraph = HyperGraph:New()
    global.forceGraphs = {}
    timer = global.timer
    timer.id = "Primary Timer"
    fullGraph = global.fullGraph
    forceGraphs = global.forceGraphs
    techTree = global.techTree
    global.techTree = timer:Do("buildTechTree")
    timer:Do("explore",fullGraph)

  end)

  script.on_load(function()
    fullGraph = HyperGraph.setmetatables(global.fullGraph)
    timer = PocketWatch.setmetatables(global.timer)
    forceGraphs = global.forceGraphs
    techTree = global.techTree
    for _, graph in pairs(forceGraphs) do
      HyperGraph.setmetatables(graph)
    end
    script.on_event(events.on_tick, timer.continueWork)
  end)

  script.on_configuration_changed(function(event)
    global.techTree = timer:Do("buildTechTree")
    timer:Do("explore", fullGraph, nil, true)
    for force, graph in pairs(global.forceGraphs) do
      timer:Do("explore", graph, force, true)
    end
  end)

  script.on_event(events.on_research_finished, function(event)
    local unlockedRecipes graph = techTree[event.research.name].unlocks, forceGraphs[event.research.force.name]
    if unlockedRecipes and graph then
      timer:Do('updatePaths', graph, unlockedRecipes)
    end
  end)

  script.on_event({
    events.on_player_created,
    events.on_player_changed_force,
  },  function(event)
    local playerID = event.player_index
    if event.name == "on_player_created" then
      timer:Do('createGUI', playerID)
    end
    local playerForce = game.players[playerID].force.name
    if not forceGraphs[playerForce] then
      forceGraphs[playerForce] = HyperGraph:New()
      timer:Do('explore', forceGraphs[playerForce], playerForce)
    end
  end)

  script.on_event({
    events.on_force_created,
    events.on_forces_merging,
  }, function(event)
    if event.name == events.on_force_created then
      forceGraphs[event.force.name] = HyperGraph:New()
      timer:Do('explore', forceGraphs[event.force.name])
    elseif event.name == events.on_forces_merging then
    forceGraphs[event.force.name] = nil
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
