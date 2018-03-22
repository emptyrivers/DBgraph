-- GUI Widgets!

-- modules
local mod_gui = require "mod-gui"
local logger  = require "misc.logger"
local HyperGraph = require "libs.HyperGraph"
local taskMap = require("libs.PocketWatch").taskmap
local inspect = require "inspect"
local lib = require "lib"
local integerize = lib.rational.integerize
-- object
local widgets = {}

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

widgets.basic_label = {
    name = "basic_label",
    prototype = {
        type = "label",
        enabled = false,
        caption = "",
    }
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
            table:Add(widgets.input_form)
            self:Add(widgets.basic_scroll_pane)
        end,
    },
}

-- misc widgets
widgets.input_form = {
    name = "Input_Form",
    prototype = {
        type = 'frame',
        direction = 'horizontal'
    },
    methods = {
        OnAdd = function(self)
            local search = self:Add(widgets.search_button)
            self:Add(widgets.input_form_elem_button)
            self:Add(widgets.input_form_add_button)
            search.result_list = self:Add(widgets.input_form_results_list)
        end
    },
    attributes = {
        target = {},
    }
}

widgets.input_form_elem_button = {
    name = "form_elem_button",
    prototype = {
        type = "choose-elem-button",
        elem_type = "signal",
    },
    methods = {
        [on_gui_elem_changed] = function(self, event)
            self.parent.target[self.name] = self.elem_value
        end,
        OnDestroy = function(self)
            self.parent.target[self.name] = nil
        end
    }
}

widgets.input_form_add_button = {
    name = "Add_More_Button",
    prototype = {
        type = 'button',
        tooltip = "click here to add another item",
        caption = '+',
    },
    methods = {
        [on_gui_click] = function(self, event)
            self:Destroy()
        end,
        OnDestroy = function(self)
            self.parent:Add(widgets.input_form_elem_button)
            self.parent:Add(widgets.input_form_add_button)
        end,
    }
}
widgets.input_form_results_list = {
  name = "input_form_results_list",
  prototype = {
    type = "frame",
    direction = "vertical",
  },
  methods = { 
    Update = function(self,result, solution, dictionary)
      self:Clear()
      game.print(result)
      if result == "finished" then    
        local recipetoint = dictionary.recipe
        for k,v in solution:elts() do
          local recipe = recipetoint[k]
          if not recipe:find("^%@PC_SOURCE%@") and not recipe:find("^%@PC_ARTIFICIAL%@") then
            self:Add(widgets.basic_label).caption = recipe..":"..v
          end
        end
      elseif result == "infeasible" then
        self:Add(widgets.basic_label).caption = solution.id.." has no valid sources"
      end
    end
  }
}
widgets.search_button = {
    name = "search_button",
    prototype = {
        type = "button",
        style = mod_gui.button_style,
        caption = "Search"
    },
    methods = {
        [on_gui_click] = function(self,event)
            local t,i = {},1
            for k, v in pairs(self.parent.target) do
                t[v.name] = i
                i = i + 1
            end
            game.print("received request for: "..inspect(t))
            global.timers.main:Do("BeginProblem", global.timers.main, 'fullGraph', t, self.result_list)
        end,
    },
    attributes = {
      result_list = 'table'
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