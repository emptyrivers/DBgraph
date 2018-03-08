-- GUI implementation

-- modules
local mod_gui     = require "mod-gui"
local util        = require "util"
local PocketWatch = require "modules.PocketWatch"
local snippets    = require "modules.snippets"
local logger      = require "logger"
local widgets     = require "modules.widgets"
local inspect     = require "inspect"
-- object
local GUI = {}

-- metatables
local elementMt = { 
  __index = function(t,k)
    if type(k) == "number" then -- event ids are numbers
      logger:log(1, "A gui event occured for a gui element with no response", "error")
    end
    return GUI[k] or t.__element[k]
  end,
  __newindex = function(t,k,v)
    t.__element[k] = v
  end, 
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
  for id in pairs(models) do
    models[id] = self:New(id)
    models[id].top:Add(widgets.TopButton)
  end
  return models
end

-- methods

function GUI:setmetatable(model)
  for _, child in pairs(model.__flatmap) do
    setmetatable(child, elementMt)
  end
  setmetatable(model.__flatmap, weakMt)
  return setmetatable(model, elementMt)
end

function GUI:New(playerID)
  local player = game.players[playerID]
  if not player then
    logger:log(1, "Attempt to create a GUI model for a non-existant playerID: "..(playerID or 'nil'), 'error')
    return 
  end
  local model = {
    __element = player.gui,
    __flatmap = {},
    gui = model,
    indestructible = true,
  }
  for id, method in pairs{top = 'get_button_flow',center = false,left = 'get_frame_flow'} do
    model[id] = {
      __element = method and mod_gui[method](player) or player.gui[id],
      shown = true,
      gui = model,
      parent = model,
      indestructible = true,
    }
    model.__flatmap[id] = model[id]
  end
  global.models[player.index] = model
  return self:setmetatable(model)
end

function GUI:Add(widget)
  local widget = snippets.rawcopy(widget)
  widget.prototype.name = not widget.unique and  widgets.acquireName(widget.name, self.player_index) or widget.name
  local newElement = {
    prototypeName = widget.name,
    __element = self.add(widget.prototype),
    shown = true,
    gui = self.gui,
    parent = self,
  }
  widget.prototype.name = nil
  newElement.shown = newElement.__element.style.visible and true or false
  if widget.methods then
    for eventID, method in pairs(widget.methods) do
      newElement[eventID] = method
    end
  end
  rawset(self,newElement.__element.name, setmetatable(newElement, elementMt))
  self.gui.__flatmap[newElement.name] = self[newElement.name]
  if newElement.OnAdd then
    newElement:OnAdd()
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
  self.gui.__flatmap[self.name] = nil
  if self.__element and self.__element.valid then
    self.parent[self.name] = nil
    self.__element.destroy()
    for _, child_name in pairs(self.children_names) do
      self[child_name]:Destroy()
    end
  end
end

function GUI:Clear()
  if self.OnClear then
    self:OnClear()
  end
  for _,child_name in pairs(self.children_names) do
    self[child_name]:Destroy()
  end
end

function GUI:Hide()
  self.shown = false
  self.__element.style.visible = false
  return true
end

function GUI:Show()
  self.shown = true
  self.__element.style.visible = true
  return true
end

function GUI:Toggle()
  return self.shown and self:Hide() or self:Show()
end

function GUI:Dump()
  local copy = snippets.rawcopy(self)
  copy.__flatmap = nil
  return inspect(copy)
end

--script handler
script.on_event(
  {
  on_gui_checked_state_changed,
  on_gui_click,
  on_gui_elem_changed,
  on_gui_selection_state_changed,
  on_gui_text_changed,
  }, 
  function(event)
    local model = models[event.player_index]
    if not model then
      logger:log(1,'error', "A gui event occured for a player with a non-existent model")
    end
    local element = model.__flatmap[event.element.name]
    if element then
      local response = element[event.name]
      if response then
        return response(element, event)
      end
    end
  end
)



return GUI