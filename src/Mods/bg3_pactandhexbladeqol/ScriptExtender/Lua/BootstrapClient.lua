local Common = Ext.Require("Shared/Common.lua")
local Spells = Ext.Require("Shared/Spells.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")

-- StatsLoaded fires only in the client Lua state (playbook knowledge\runtime_stats.md).
Ext.Events.StatsLoaded:Subscribe(function()
    ClientLog.Add("Stats loaded. Spells: " .. Spells.Apply() .. ".")
end)

Ext.Events.SessionLoaded:Subscribe(function()
    ClientLog.Add("Pact and Hexblade QoL " .. Common.ModVersion() .. " loaded.")
end)
