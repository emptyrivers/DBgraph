
local lib = require "lib"
local snippets = require "misc.snippets"
local logger = require "misc.logger"
local inspect = require "inspect"
local taskMap = lib.PocketWatch.taskMap

function BuildTechTree()
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
        tech.prereq[name] = false
      end
    end
  end
  return techTree
end

function BuildGraph(graph, forceName, shouldRebuild)
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
      data.prereq = global.techTree.__inverted[name]
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
  return graph
end

