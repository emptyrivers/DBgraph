

for k, v in pairs(defines.events) do
  _G[k] = v -- because fuck writing defines.events.on_whatever_event every damn time!
end


-- modules
local lib = require "lib"
local snippets = require "misc.snippets"
local logger   = require "misc.logger"
local inspect  = require "inspect"

-- upvalues
local taskMap     = lib.PocketWatch.taskMap
local responses   = lib.GUI.responses
local snippets    = snippets

-- upvalues to be assigned in init/load
local timers, fullGraph, techTree, forceGraphs, models

-- taskMap function definitions
do
  function taskMap.buildTechTree()
    --we only care about techs that unlock recipes...
    local techTree = { __inverted = {} }
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
      if prototype.type == "offshore-pump" then
        local data = {
          id = "@PC_SOURCE@"..prototype.fluid.name..'@'..name..'@',
          isFakeRecipe = true,
          category = name,
          enabled = true,
          energy = 0,
          ingredients = {["@PC_SOURCE@"..name] = 1},
          products = { [prototype.fluid.name] = 60 * prototype.pumping_speed},
        }
        graph:AddNode({type = "SOURCE", id = "@PC_SOURCE@"..name})
        if not graph.nodes[prototype.fluid.name] then
          graph:AddNode({type = "fluid", id = prototype.fluid.name})
        end
        graph:AddEdge(data)
      elseif prototype.type == "resource" then
          local properties = prototype.mineable_properties
          local data = {
            id = "@PC_SOURCE@" .. name,
            isFakeRecipe = true,
            category = prototype.resource_category,
            enabled = true,
            energy = properties.mining_time,
            ingredients = {},
            products = {},
          }
          local sourceNode = properties.required_fluid
          if sourceNode then
            if not graph.nodes[sourceNode] then
              graph:AddNode({type = "fluid", id = properties.required_fluid})
            end
            data.ingredients[properties.required_fluid] = properties.fluid_amount
          else
            graph:AddNode({type = "SOURCE", id = "@PC_SOURCE@"..name})
            data.ingredients["@PC_SOURCE@"..name] = 1
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
        if table_size(recipe.ingredients) ~= 0 then
          for _, ingredient in ipairs(recipe.ingredients) do
            local name = ingredient.name
            if not graph.nodes[name] then           
              graph:AddNode({id = name, type = ingredient.type})
            end
            data.ingredients[name] = ingredient.amount
          end
        else --this is a source!
          graph:AddNode({type = "SOURCE", id = "@PC_SOURCE@"..name})
          data.ingredients["@PC_SOURCE@"..name] = 1
        end
        for _, product in ipairs(recipe.products) do
          local name = product.name
          if not graph.nodes[name] then           
            graph:AddNode({id = name, type = product.type})
          end
          data.products[name] = product.amount or (product.probability * .5 * (product.amount_min + product.amount_max))
        end
        for id, amount in pairs(data.ingredients) do
          if data.products[id] then
            data.catalysts = data.catalysts or {}
            local diff = data.products[id] - amount
            if diff < 0 then
              data.catalysts[id] = data.products[id]
              data.ingredients[id] = -diff
              data.products[id] = nil
            else
              data.products[id] = diff
              data.ingredients[id] = nil
              data.catalysts[id] = amount
            end
          end
        end
        graph:AddEdge(data)
      end
    end
    return 
  end
  function taskMap.nothing()
  end

end

-- script handlers
script.on_init(function()
  lib:Init()
  fullGraph,        forceGraphs,        timers,        models,        techTree =
  global.fullGraph, global.forceGraphs, global.timers, global.models
  timer = lib.PocketWatch:New('main')
  global.techTree = timers.main:Do("buildTechTree")
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
  playermodel.top:Add(modules.widgets.Top_Button)
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