-- GUI implementation

-- modules
local mod_gui     = require "mod-gui"
local util        = require "util"
local PocketWatch = require "modules.PocketWatch"
local snippets    = require "modules.snippets"

-- GUI object
local GUI = {
  templates = {},
  responses = {
    [defines.events.on_gui_click] = {},
    [defines.events.on_gui_checked_state_changed] = {},
    [defines.events.on_gui_elem_changed] = {},
    [defines.events.on_gui_selection_state_changed] = {},
    [defines.events.on_gui_text_changed] = {},
  }
}

-- metatables
local guiMt  = { __index = GUI }
local weakMt = { __mode  = "kv"}
-- upvalues 
local get_button_flow                = mod_gui.get_button_flow
local get_frame_flow                 = mod_gui.get_frame_flow
local templates                      = GUI.templates
local responses                      = GUI.responses
local on_gui_click                   = responses[defines.events.on_gui_click]
local on_gui_checked_state_changed   = responses[defines.events.on_gui_checked_state_changed]
local on_gui,elem_changed            = responses[defines.events.on_gui_elem_changed]
local on_gui_selection_state_changed = responses[defines.events.on_gui_selection_state_changed]
local on_gui_text_changed            = responses[defines.events.on_gui_text_changed]
local taskMap                        = PocketWatch.taskMap
local wipe                           = snippets.wipe
local trueFunc                       = snippets.trueFunc

-- future upvalues for init/load
local models, recursiveMetatable, recursiveAdd

-- Init/load/config scripts
function GUI:Init()
  global.models = {}
  models = global.models
  return models
end

function GUI:Load()
  for _, model in pairs(global.models) do
    self.setmetables(model)
  end
  return models
end

function GUI:OnConfigurationChanged()
  --there might be things in the gui which are invalid
  for _,model in pairs(global.guimodels) do
    model:Reset()
  end
end

-- methods
function GUI:New(playerID)
  if not playerID then return end
  local player = game.players[playerID]
  if not player then 
    return 
  else
    local model = {
      gui = player.gui,
      flatmap = {}, -- flatmap is a weak reference, used only for quickly accessing gui elements
      shown   = true,
    }
    for _, id in pairs{'top', 'left', 'center'} do
      local element = player.gui[id]
      model[id] = {
        name = id,
        element = element,
        indestructible = true,
        IsVisible = trueFunc,
        model = model,
        shown = true,
      }
      model.flatmap[id] = model[id]
    end
    models[player.index] = model
    return self.setmetatables(model)
  end
end

function GUI:Delete(playerID)
  if not playerID then return end
  local player = game.players[playerID]
  if not player then return end
  models[player.index] = nil
end

function recursiveMetatable(element) -- helper function
  setmetatable(element, guiMt)
  if element.children then
    for _, child in pairs(element.children) do
      recursiveMetatable(child)
    end
  end
end

function GUI.setmetatables(model)
  setmetatable(model.flatmap, weakMt)
  for _, id in pairs{'top', 'left', 'center'} do
    local element = model[id]
    recursiveMetatable(element)
  end
  return model
end

function GUI:Add(toAdd) -- toAdd is assumed to be a valid datum for LuaGuiElement.add
  toAdd = table.deepcopy(toAdd)
  toAdd.element = self.element.add()
  self.children[toAdd.name] = toAdd
  toAdd.parent = self
  toAdd.model  = self.parent.model
  toAdd.model.flatmap[toAdd.name] = toAdd
  toAdd.children = {}
  return setmetatable(toAdd, guiMt)
end

function GUI:Destroy()
  if self.indestructible then return end
  self.parent.children[self.name] = nil
  self.element.destroy()
end

function GUI:Clear()
  self.element.clear()
  wipe(self.children)
end

function GUI:Hide()
  self.shown = false
  self.element = self.element.destroy()
end

function recursiveAdd(model)
  model.parent.element.add(element)
  for _, child in pairs(model.children) do
    recursiveAdd(child)
  end
end

function GUI:Show()
  self.shown = true
  recursiveAdd(self)
end

function GUI:Toggle()
  if self.shown then
    self:Hide()
  else
    self:Show()
  end
end

function GUI:IsVisible()
  if not self.shown then return false end
  return self.parent:IsVisible()
end


function GUI:Reset()

end

return GUI