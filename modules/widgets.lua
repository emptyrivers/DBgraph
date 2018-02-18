-- GUI Widgets!

-- modules
local mod_gui = require "mod-gui"
local modules = {
    HyperGraph  = require "modules.HyperGraph",
    PocketWatch = require "modules.PocketWatch",
    Chain       = require "modules.Chain",
    GUI         = require "modules.GUI",
}

-- object
local widgets = {}

widgets.TopButton = {
    prototype = {
        type    = "button",
        name    = "PC_TopButton",
        style   =  mod_gui.button_style,
        caption = "PC",
    },
    indestructible = true,
    responses = {
        OnAdd = function(self)
            local MainFrame = self.model.left:Add(widgets.MainFrame)
            MainFrame:Hide()
        end,
        [defines.events.on_gui_click] = function(self, event)
            self.model.left.PC_MainFrame:Toggle()
        end,
    },
}
widgets.MainFrame = {
    prototype = {
        type = "frame",
        name = "PC_MainFrame",
        style = mod_gui.frame_style,
        caption = "TEST"
    },
    responses = {},
}


return widgets