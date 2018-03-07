-- GUI Widgets!

-- modules
local mod_gui = require "mod-gui"
local logger  = require "modules.logger"
local HyperGraph = require "modules.HyperGraph"
-- object
local widgets = {}

local pool 


-- init/load
function widgets.Init()
    global.pool = {}
    pool = global.pool
end

function widgets.Load()
    pool = global.pool
end

-- helper functions
function widgets.acquireName(name, playerID)
    pool[playerID] = pool[playerID] or {}
    local playerPool = pool[playerID]
    local id = playerPool[name] or 1
    playerPool[name] = id + 1
    return ("PC_%s:%s:%s"):format(name,playerID,id), id
end


-- the widgets themselves


-- simple widgets - these have no methods, and respond to no events.
widgets.basic_row = {
    name = "basic_row",
    prototype = {
        type = "flow",
        style = "horizontal_flow",
        enabled = false,
    },
}

widgets.basic_column = {
    name = "basic_column",
    prototype = {
        type = "vertical-flow",
        style = "vertical_flow",
        enabled = false,
    }
}
widgets.basic_table = {
    name = "basic_table",
    prototype = {
        type = "table",
        column_count = 3,
        enabled = false,
    }
}

widgets.basic_scroll_pane = {
    name = "basic_scroll_pane",
    prototype = {
        type = "scroll-pane",
        enabled = false,
    },
}


-- unique widgets (special, have lots of methods usually)
widgets.Top_Button = {
    name = "PC_Top_Button",
    unique = true,
    indestructible = true,
    prototype = {
        type    = "button",
        style   =  mod_gui.button_style,
        caption = "PC",
        tooltip = {"","Left Click to bring up status, right click to open main menu."}
    },
    methods = {
        OnAdd = function(self)
            self.gui.left:Add(widgets.Left_Frame):Hide()
            self.gui.center:Add(widgets.Center_Frame):Hide()
            logger:log(4,"file",{data = self.gui:Dump(), filePath = "GUI_Log",for_player = self.player_index})
        end,
        [on_gui_click] = function(self, event)
            if event.button == defines.mouse_button_type.right then
                self.gui.center.PC_Center_Frame:Toggle()
            else
                self.gui.left.PC_Left_Frame:Toggle()
            end
        end,
    },
}

widgets.Left_Frame = {
    name = 'PC_Left_Frame',
    unique = true,
    indestructible = true,
    prototype = {
        type = "frame",
        style = mod_gui.frame_style,
        caption = "Production Chains",
        enabled = false,
        direaction = "vertical",
    },
    methods = {            
        OnAdd = function(self)
            local table = self:Add(widgets.basic_table)
            table:Add(widgets.search_button)
            table:Add(widgets.help_button)
        end,
    }
}

widgets.Center_Frame = {
    name = 'PC_Center_Frame',
    unique = true,
    indestructible = true,
    prototype = {
        type = "frame",
        style = mod_gui.frame_style,
        caption = "Center!",
        enabled = false,
        direction = horizontal
    },
    methods = {
        OnAdd = function(self)
            local table = self:Add(widgets.basic_table)
            table.draw_horizontal_line_after_headers = true
            table:Add(widgets.search_button)
            self:Add(widgets.basic_scroll_pane)
        end,
    },
}

-- misc widgets
widgets.search_button = {
    name = "search_button",
    prototype = {
        type = "button",
        style = mod_gui.button_style,
        caption = "Search"
    },
    methods = {
        [on_gui_click] = function(self,event)
            local itemStack = game.players[self.player_index].cursor_stack
            if itemStack.valid_for_read then
                game.players[self.player_index].print{'You clicked with a __1__ in your hand!', itemStack.prototype.localised_name}
            else
                game.players[self.player_index].print("Your hands are empty!")
            end
        end,
    }
}

widgets.help_button = {
    name = "help_button",
    prototype = {
        type = "button",
        style = mod_gui.button_style,
        caption = "?"
    },
    methods = {
        [on_gui_click] = function(self,event)
            game.players[event.player_index].print("This is a help button!")
        end
    }
}

return widgets