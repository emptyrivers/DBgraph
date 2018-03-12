local GUI = {}

-- requires
local mod_gui = require "mod-gui"
require "util"
local inspect = require "inspect"
local snippets = require "misc.snippets"

-- metatables
local elementMt = { 
  __index = function(self,key)
    if type(key) == "number" then -- event ids are numbers
      -- error("A gui event occured for a gui element with no response")
      return -- uncomment the last line if you wish
    end
    return GUI[key] or self.__element[key]
  end,
  __newindex = function(self,key,value)
    self.__element[key] = value
  end, 
}
local namePoolMt = {
  __index = function(self,key)
    self[key] = 1
    return 1
  end
}

--  future upvalues
local models, namePool

-- Init/load/config scripts
function GUI:Init()
  global.namePool = {}
  global.models = {}
  models, namePool = global.models, global.namePool
  return global.models, global.namePool
end

function GUI:Load()
  for _,model in pairs(global.models) do
    self:setmetatable(model)
  end
  models, namePool = global.models, global.namePool
  return global.models, global.namePool
end

function GUI:OnConfigurationChanged()
  --dummy function, fill in with the edits to gui models which best suits your purposes
end

-- methods

function GUI:setmetatable(model)
  for _, child in pairs(model.__flatmap) do
    setmetatable(child, elementMt)
  end
  setmetatable(global.namePool[model.__element.player.index], namePoolMt)
  return setmetatable(model, elementMt)
end

function GUI:New(playerID)
  local player = game.players[playerID]
  if not player then
    error("Attempt to create a GUI model for a non-existant playerID: "..(playerID or 'nil'))
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
  global.namePool[player.index] = {}
  global.models[player.index] = model
  return self:setmetatable(model)
end

function GUI:Delete(playerID)
  local index = game.players[playerID].index -- there are more valid playerIDs then necessary, so get the uint version
  global.namePool[index] = nil
  global.models[index] = nil
end

-- helper function for Add
function AcquireName(name, playerID)  
  -- we could also release the name on GUI:PreDestroy(), i suppose. But that would require keeping a much larger data structure.
  -- In practice, this will never cause collisions, since lua uses doubles for numbers, and it would overflow at 2^54
  local pool = namePool[game.players[playerID].index]
  local id = pool[name]
  pool[name] = pool[name] + 1
  return ("GUI_%s:%s:%s"):format(name,playerID,id),id  
end
  
function GUI:Add(widget)
  widget.prototype.name = not widget.unique and  AcquireName(widget.name, self.player_index) or widget.name
  local newElement = {
    prototypeName = widget.name,
    __element = self.add(widget.prototype),
    gui = self.gui, 
    parent = self,
  }
  widget.prototype.name = nil
  if widget.methods then
    for eventID, method in pairs(widget.methods) do
      newElement[eventID] = method
    end
  end
  if widget.attributes then
    local attributes = table.deepcopy(widget.attributes)
    for attributeID, attribute in pairs(attributes) do
      newElement[attributeID] = attribute
    end
  end
  --rawset because the parent of this new element already has a __newindex method, and it would try to write to the LuaGuiElement, causing an error
  rawset(self,newElement.__element.name, setmetatable(newElement, elementMt)) 
  self.gui.__flatmap[newElement.name] = self[newElement.name]
  if newElement.OnAdd then
    newElement:OnAdd()
  end
  return newElement
end

function GUI:PreDestroy(...)
  if self.OnDestroy then
    self:OnDestroy(...)
  end
  self.gui.__flatmap[self.name] = nil
  for _, child_name in pairs(self.children_names) do
    self[child_name]:PreDestroy(...)
  end
end

function GUI:Destroy(...)
  if self.indestructible then 
    error("Attempt to destroy indestructible element: "..self.name)
  end
  self:PreDestroy(...)
  self.parent[self.name] = nil
  self.__element.destroy()
end

function GUI:Clear(...)
  if self.OnClear then
    self:OnClear(...)
  end
  for _,child_name in pairs(self.children_names) do
    self[child_name]:PreDestroy(...)
    self[child_name] = nil
  end
  self.__element.clear()
end

function GUI:Hide()
  self.__element.style.visible = false
  return true
end

function GUI:Show()
  self.__element.style.visible = true
  return true
end

function GUI:Toggle()
  return self.__element.style.visible and self:Hide() or self:Show()
end

function GUI:Dump()
  local copy = snippets.rawcopy(self)
  copy.__flatmap = nil
  return inspect(copy)
end

--script handler
script.on_event(
  {
  defines.events.on_gui_checked_state_changed,
  defines.events.on_gui_click,
  defines.events.on_gui_elem_changed,
  defines.events.on_gui_selection_state_changed,
  defines.events.on_gui_text_changed,
  }, 
  function(event)
    local model = models[event.player_index]
    if not model then
      -- error("A gui event occured for a player with a non-existent model")
      return
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