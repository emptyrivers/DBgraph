-- Top Button template

-- modules
local mod_gui = require "mod-gui"

local TopButton = {
    type    = "button",
    name    = "PC_TopButton",
    style   =  mod_gui.button_style,
    caption = "PC",
    indestructible = true,
    [defines.events.on_gui_click] = function(self, event)
    end
}

return TopButton