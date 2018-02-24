for k, v in pairs(defines.events) do
  _G[k] = v -- because fuck writing defines.events.on_whatever_event every damn time!
end
-- modules
local modules = {
  HyperGraph   = require "modules.HyperGraph",
  PocketWatch  = require "modules.PocketWatch",
  Chain        = require "modules.Chain",
  GUI          = require "modules.GUI",
}
local widgets  = require "modules.widgets"
local snippets = require "modules.snippets"
local logger   = require "modules.logger"
local inspect  = require "inspect"
-- upvalues
local taskMap     = modules.PocketWatch.taskMap
local responses   = modules.GUI.responses
local snippets    = snippets

-- upvalues to be assigned in init/load
local timer, fullGraph, techTree, forceGraphs, models

-- 



-- taskMap function definitions
do
  function taskMap.buildTechTree()
    --we only care about techs that unlock recipes...
    techTree = { __inverted = {} }
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
            techTree.__inverted[effect.recipe] = data
            table.insert(stack, data)
          else
            techTree.__inverted[effect.recipe] = techTree[name]
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
    if shouldRebuild then
      for id in pairs(graph.nodes) do
        graph:RemoveNode(id)
      end
    end
    for name, prototype in pairs(game.entity_prototypes) do
      if prototype.valid and prototype.type == "resource" then
          local properties = prototype.mineable_properties
          local data = {
            id = name,
            isFakeRecipe = true,
            category = prototype.resource_category,
            enabled = true,
            energy = properties.mining_time,
            ingredients = {},
            products = {},
          }
          if properties.required_fluid then
            if not graph.nodes[properties.required_fluid] then
              graph:AddNode({type = "fluid", id = properties.required_fluid})
            end
            data.ingredients[properties.required_fluid] = properties.fluid_amount
          end
          for _, product in ipairs(properties.products) do
            local name = product.name
            if not graph.nodes[name] then           
              graph:AddNode({id = name, type = product.type})
            end
            data.products[product.name] = product.amount or (product.probability * .5 * (product.amount_min + product.amount_max))
          end
          graph:AddEdge(data)
      end
    end
    local recipes = forceName and game.forces[forceName].recipes or game.recipe_prototypes
    for name, recipe in pairs(recipes) do
      local redundant = snippets.redundancyType(recipe)
      if not redundant then
        local data = {
          id = name,
          category = recipe.category,
          enabled = recipe.enabled,
          energy = recipe.energy,
          ingredients = {},
          products = {},
        }
        data.prereq = techTree.__inverted[name]
        for _, ingredient in ipairs(recipe.ingredients) do
          local name = ingredient.name
          if not graph.nodes[name] then           
            graph:AddNode({id = name, type = ingredient.type})
          end
          data.ingredients[name] = ingredient.amount
        end
        for _, product in ipairs(recipe.products) do
          local name = product.name
          if not graph.nodes[name] then           
            graph:AddNode({id = name, type = product.type})
          end
          data.products[name] = product.amount or (product.probability * .5 * (product.amount_min + product.amount_max))
        end
        graph:AddEdge(data)
      end
    end
    return 

  end

  function taskMap.createPaths(graph)
  end

  function taskMap.updatePaths(graph, recipes)
  end

  function taskMap.nothing()
  end

end

-- script handlers
do
  script.on_init(function()
    -- create persistent values
    fullGraph, forceGraphs = modules.HyperGraph:Init()
    modules.PocketWatch:Init()
    timer = modules.PocketWatch:New('control')
    models = modules.GUI:Init()
    widgets.Init()
    global.techTree = timer:Do("buildTechTree")
    techTree = global.techTree
    timer:Do("explore",fullGraph)
    commands.add_command("pc","test",function() game.print("Hello, World!")end)
  end)

  script.on_load(function()
    fullGraph, forceGraphs = modules.HyperGraph:Load()
    timer  = modules.PocketWatch:Load(global.timer).control
    models = modules.GUI:Load()
    widgets.Load()
    techTree = global.techTree
    if timer.working then
      script.on_event(on_tick, timer.continueWork)
    end
    commands.add_command("pc","test",function() game.print("Hello, World!")end)
  end)

  script.on_configuration_changed(function(event)
    modules.GUI.OnConfigurationChanged()
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
      forceGraphs[playerForce] = HyperGraph:New()
      timer:Do('explore', forceGraphs[playerForce], playerForce)
    end
  end)

  script.on_event(on_player_created, function(event)
    local playermodel = modules.GUI:New(event.player_index)
    playermodel.top:Add(widgets.Top_Button)
    logger:log(1,'file',{filePath = "GUI_Log",data = playermodel:Dump(), for_player = event.player_index})
  end)

  script.on_event(on_player_removed, function(event)
    modules.GUI:Delete(event.player_index)
  end)

  script.on_event(on_forces_merging, function(event)
      forceGraphs[event.force.name] = nil
    end
  )
end



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