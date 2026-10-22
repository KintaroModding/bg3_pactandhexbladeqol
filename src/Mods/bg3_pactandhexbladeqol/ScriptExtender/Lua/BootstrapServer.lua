local Common = Ext.Require("Shared/Common.lua")
local Spells = Ext.Require("Shared/Spells.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    ServerLog.Add("Pact and Hexblade QoL " .. Common.ModVersion() .. " loaded.")
    ServerLog.Add("Spells: " .. Spells.Apply() .. ".")
end)

local Binding = Ext.Require("Server/Binding.lua")
Binding.Init()

local Bg3DnDNotice = Ext.Require("Server/Bg3DnDNotice.lua")
Bg3DnDNotice.Init()
