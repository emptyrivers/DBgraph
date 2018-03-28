
local libs = {
    vector = require "libs.vector",
    matrix = require "libs.matrix",
    HyperGraph = require "libs.HyperGraph",
    PocketWatch = require "libs.PocketWatch",
    GUI = require "libs.GUI",
}

local lib = {}
function repairMetatables(broken) --should do this smarter, not harder
    local seen = {}
    local function _recurse(t)
        if type(t) == "table" then 
            if type(t.__self) ~= 'userdata' then -- no touching userdata
                local mt = t.type and libs[t.type] and libs[t.type].mt
                if mt then
                    setmetatable(t,mt)
                end
                for k,v in pairs(t) do
                    if type(k) == "table" and not seen[k] then
                        seen[k] = true
                        _recurse(k)
                    end
                    if type(v) == "table" and not seen[v] then
                        seen[v] = true
                        _recurse(v)
                    end
                end
            end
        end
    end
    _recurse(broken)
end
function lib:Init()
    for k, v in pairs(libs) do
        if v.Init then
            v:Init()
        end
    end
end
function lib:Load()
    repairMetatables(global)
    for _, v in pairs(libs) do
        if v.Load then
            v:Load()
        end
    end
end
function lib:OnConfigurationChanged()
    for _, v in pairs(libs) do
        if v.OnConfigurationChanged then
            v:OnConfigurationChanged()
        end
    end
end
for k,v in pairs(libs) do
    lib[k] = v
end
    
return lib