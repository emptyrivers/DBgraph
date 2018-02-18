-- GUI implementation

-- modules
local mod_gui     = require "mod-gui"
local util        = require "util"
local PocketWatch = require "modules.PocketWatch"
local snippets    = require "modules.snippets"
local logger      = require "logger"

-- object
local GUI = {}

-- metatables
local elementMt = { 
  __index = function(t,k)
    if type(k) == "number" then -- event ids are numbers
      logger:log(1, "A gui event occured for a gui element with no response", "error")
    end
    return GUI[k] or t.element[k]
  end,
  __newindex = function(t,k,v)
    t.element[k] = v
  end, 
}
local guiMt = { 
  __index =function(t,k)
    return GUI[k] or t.gui[k]
  end
 }
local weakMt = { __mode = "kv" }

-- upvalues 
local timer = PocketWatch:New("gui")

-- future upvalues for init/load
local models

-- Init/load/config scripts
function GUI:Init()
  global.models = {}
  models = global.models
  return global.models
end

function GUI:Load()
  for _,model in pairs(global.models) do
    self:setmetatable(model)
  end
  models = global.models
  return global.models
end

function GUI:OnConfigurationChanged()
  for _,model in pairs(global.models) do
    model:Reset()
  end
  return global.models
end

-- methods
function GUI.respond(event)
  local model = models[event.player_index]
    if not model then
      logger:log(1, "A gui event occured for a player with a non-existent model", "error")
    end
    local element = model._flatmap[event.element.name]
    if element then
      logger:log(4,"gui element: "..event.element.name.." has been affected")
      local response = element[event.name]
      if response then
        logger:log(4,"beginning response")
        return response(element, event)
      end
    end
end

function GUI:setmetatable(model)
  local function recurse(child)
    setmetatable(child, elementMt)
    for _, grandchild in pairs(child.children) do
      recurse(grandchild)
    end
  end
  for _, child in pairs(model.children) do
    recurse(children)
  end
  setmetatable(model._flatmap, weakMt)
  return setmetatable(model, guiMt)
end

function GUI:New(playerID)
  local player = game.players[playerID]
  if not player then
    logger:log(1, "Attempt to create a GUI model for a non-existant playerID: "..(playerID or 'nil'), 'error')
    return 
  end
  local model = setmetatable({
    gui = player.gui,
    _flatmap = {},
  }, guiMt)
  for _, id in pairs{'top','center','left'} do
    model[id] = setmetatable({
      element = player.gui[id],
      shown = true,
      gui = model,
      parent = model,
      indestructible = true,
    }, elementMt)
    model._flatmap[id] = model.children[id]
  end
  global.models[player.index] = model
  return model
end

function GUI:Add(widget)
  local newElement = {
    element = self.add(widget.prototype),
    shown = true,
    gui = self.gui,
    parent = self,
    OnAdd = widget.OnAdd,
    OnDestroy = widget.OnDestroy,
    OnClear = widget.OnClear,
  }
  newElement.shown = newElement.element.style.visible and true or false
  for eventID, response in pairs(widget.responses) do
    newElement[eventID] = response
  end
  rawset(self,newElement.element.name, setmetatable(newElement, elementMt))
  self.gui._flatmap[newElement.name] = self[newElement.name]
  if newElement.OnAdd then
    newElement:OnAdd(newElement)
  end
  return newElement
end

function GUI:Destroy()
  if self.indestructible then 
    logger:log(1, "Attempt to destroy indestructible element: "..self.name, "error")
    return
  end
  if self.OnDestroy then
    self:OnDestroy()
  end
  self.parent[self.name] = nil
  self.element.destroy()
end

function GUI:Clear()
  if self.OnClear then
    self:OnClear()
  end
  for _,id in pairs(self.children_names) do
    self[id] = nil
  end
  self.element.clear()
end

function GUI:Hide()
  self.shown = false
  self.element.style.visible = false
  return true
end

function GUI:Show()
  self.shown = true
  self.element.style.visible = true
  return true
end

function GUI:Toggle()
  return self.shown and self:Hide() or self:Show()
end

function GUI.Reset(model) -- dummy function until i know exactly what to reset to. 
  if not model.gui then return end
end

return GUI