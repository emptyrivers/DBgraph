-- modules
HyperGraph  = require "modules.HyperGraph"
PocketWatch = require "modules.PocketWatch"
Chain       = require "modules.Chain"
GUI         = require "modules.GUI"

-- upvalues
local HyperGraph  = HyperGraph
local PocketWatch = PocketWatch
local Chain       = Chain
local GUI         = GUI
local events      = defines.events
local taskMap     = PocketWatch.taskMap
local responses   = GUI.responses

-- upvalues to be assigned later
local timer, fullGraph, techTree, forceGraphs


-- taskMap function definitions
do
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
    return techTree
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

end

-- script handlers
do
  script.on_init(function()
    -- create persistent values
    global.timer       = PocketWatch:New()
    global.fullGraph   = HyperGraph:New()
    global.forceGraphs = {}
    -- GUI.Init()
    timer = global.timer
    timer.id = "Primary Timer"
    fullGraph = global.fullGraph
    forceGraphs = global.forceGraphs
    global.techTree = timer:Do("buildTechTree")
    timer:Do("explore",fullGraph)
  end)

  script.on_load(function()
    fullGraph   = HyperGraph.setmetatables(global.fullGraph)
    timer       = PocketWatch.setmetatables(global.timer)
    forceGraphs = global.forceGraphs
    techTree    = global.techTree

    -- GUI.Load()
    for _, graph in pairs(forceGraphs) do
      HyperGraph.setmetatables(graph)
    end
    if timer.working then
      script.on_event(events.on_tick, timer.continueWork)
    end
  end)

  script.on_configuration_changed(function(event)
    global.techTree = timer:Do("buildTechTree")
    timer:Do("explore", fullGraph, nil, true)
    for force, graph in pairs(global.forceGraphs) do
      timer:Do("explore", graph, force, true)
    end
  end)

  script.on_event(events.on_research_finished, function(event)
    game.print(serpent.block(techtree[event.research.name]))
    local unlockedRecipes = techTree[event.research.name].unlocks
    local graph =  forceGraphs[event.research.force.name]
    if unlockedRecipes and graph then
      timer:Do('updatePaths', graph, unlockedRecipes)
    end
  end)

  script.on_event({
      events.on_player_created,
      events.on_player_changed_force,
    },  
    function(event)
      local playerID = event.player_index
      if event.name == events.on_player_created then
        GUI.CreateMainButton(playerID)
      end
      local playerForce = game.players[playerID].force.name
      if not forceGraphs[playerForce] then
        forceGraphs[playerForce] = HyperGraph:New()
        timer:Do('explore', forceGraphs[playerForce], playerForce)
      end
    end
  )

  script.on_event({
    events.on_force_created,
    events.on_forces_merging,
    }, 
    function(event)
      if event.name == events.on_force_created then
        forceGraphs[event.force.name] = HyperGraph:New()
        timer:Do('explore', forceGraphs[event.force.name])
      elseif event.name == events.on_forces_merging then
      forceGraphs[event.force.name] = nil
      end
    end
  )
--[[
  script.on_event({
    events.on_gui_checked_state_changed,
    events.on_gui_click,
    events.on_gui_elem_changed,
    events.on_gui_selection_state_changed,
    events.on_gui_text_changed,
  },
  function(event)
    if event.element.valid then
      local id, element, player = event.name, event.element, event.element.player_index
      game.print(id..','..player..','..element.name)
      local response = responses[element.name]
      
      if response then
        game.print'responding'
        return response(player, element, id)
      end
    end
  end)
  --]]
end
