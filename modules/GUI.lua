
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

local guiMt = { __index = GUI }
-- submodules
local mod_gui = require "mod-gui"
local util    = require "util"

-- upvalues (since lua isn't so keen on accessing globals or indexing tables)
local get_button_flow                = mod_gui.get_button_flow
local get_frame_flow                 = mod_gui.get_frame_flow
local templates                      = GUI.templates
local responses                      = GUI.responses
local on_gui_click                   = responses[defines.events.on_gui_click]
local on_gui_checked_state_changed   = responses[defines.events.on_gui_checked_state_changed]
local on_gui,elem_changed            = responses[defines.events.on_gui_elem_changed]
local on_gui_selection_state_changed = responses[defines.events.on_gui_selection_state_changed]
local on_gui_text_changed            = responses[defines.events.on_gui_text_changed]

-- future upvalue during runtime
local models

return GUI
