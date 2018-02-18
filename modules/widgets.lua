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
    indestructible = true,
    prototype = {
        type    = "button",
        name    = "PC_TopButton",
        style   =  mod_gui.button_style,
        caption = "PC",
    },
    OnAdd = function(self)
        local MainFrame = self.gui.left:Add(widgets.MainFrame)
        MainFrame:Hide()
    end,
    responses = {

        [defines.events.on_gui_click] = function(self, event)
            self.gui.left.PC_MainFrame:Toggle()
        end,
    },
}
widgets.MainFrame = {
    indestructible = true,
    prototype = {
        type = "frame",
        name = "PC_MainFrame",
        style = mod_gui.frame_style,
        caption = "TEST"
    },
    responses = {},
}


return widgets