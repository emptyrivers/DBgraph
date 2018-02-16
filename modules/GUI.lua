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
local guiMt = { __index = GUI }

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
    models[player.index] = {
      gui = player.gui,
      top     = {
        element = player.gui.top,
        indestructible = true,
        IsVisible = trueFunc,
      },
      center  = {
        element = player.gui.center,
        indestructible = true,
        IsVisible = trueFunc,
      },
      left    = {
        element = player.gui.left,
        indestructible = true,
        IsVisible = trueFunc,
      },
      shown   = true,
    }
  end
  return self.setmetatables(models[player.index])
end


function recursiveMetatable(element) -- helper function
  setmetatable(element, guiMt)
  for _, child in pairs(element.children) do
    recurse(child)
  end
end

function GUI.setmetables(model)
  for _, id in pairs{'top', 'left', 'center'} do
    local element = model[id]
    recurse(element)
  end
  return model
end

function GUI:Add(toAdd)
  toAdd.element = self.element.add()
  self.children[toAdd.name] = toAdd
  toAdd.parent = self
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

return GUI