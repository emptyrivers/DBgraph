

local lib = {
    HyperGraph = require "libs.HyperGraph",
    PocketWatch = require "libs.PocketWatch",
    GUI = require "libs.GUI",
    vector = require "libs.vector",
    matrix = require "libs.matrix",
}
function lib:Init()
    for _, v in pairs(lib) do
        if v.Init then
            v:Init()
        end
    end
end
function lib:Load()
    for _, v in pairs(lib) do
        if v.Load then
            v:Load()
        end
    end
end
function lib:OnConfigurationChanged()
    for _, v in pairs(lib) do
        if v.OnConfigurationChanged then
            v:OnConfigurationChanged()
        end
    end
end


return libs