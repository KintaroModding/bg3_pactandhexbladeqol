-- The spell changes: the client applies them when the stats load, the server again on each session load.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }

local syncs = {}

--- A stats object with the game's values (Patch 8 SharedDev data) and a Sync counter.
local function Spell(name, fields)
    fields.Sync = function()
        syncs[name] = (syncs[name] or 0) + 1
    end
    Harness.Stats[name] = fields
    return fields
end

local summon = Spell("Shout_PactOfTheBlade", { Cooldown = "OncePerCombat" })
local bind = Spell("Shout_PactOfTheBlade_Bind", {
    Description = "hgameDescription;1", ExtraDescription = "hgameExtra;1", TooltipPermanentWarnings = "",
    Requirements = { { Not = true, Requirement = "Combat" } }, UseCosts = "ActionPoint:1",
})
local bond = Spell("Shout_WeaponBond", { Requirements = { { Not = true, Requirement = "Combat" } },
    UseCosts = "ActionPoint:1" })
-- The Hexblade entries are left out: the test checks that a missing entry is logged, not an error.

Ext.Require("BootstrapServer.lua")
Ext.Require("BootstrapClient.lua")
local Spells = Ext.Require("Shared/Spells.lua")

local function Log(name)
    Harness.RunTimers()
    return Harness.Files["bg3_pactandhexbladeqol/" .. name] or ""
end

Test("the client changes the spells when the stats load", function()
    Ext.Events.StatsLoaded:Fire()
    AssertEq(summon.Cooldown, "None", "no cooldown on the pact weapon summon")
    AssertEq(bind.UseCosts, "", "free bind")
    AssertEq(#bind.Requirements, 0, "bind in combat too")
    AssertEq(bind.Description, "h5598e728gfe9dg430cg83a0g24a3d7ab856e", "new description")
    AssertEq(bind.ExtraDescription, "", "no extra description")
    AssertEq(bind.TooltipPermanentWarnings, "875a0531-aa45-49ce-880c-e258c24db99c", "unbind warning")
    AssertEq(bond.UseCosts, "", "free Weapon Bond")
    AssertEq(#bond.Requirements, 0, "Weapon Bond in combat too")
    AssertEq(syncs.Shout_PactOfTheBlade_Bind, 1, "synced once")
    AssertTrue(string.find(Log("client.log"), "Stats loaded. Spells: Shout_PactOfTheBlade changed, Shout_PactOfTheBlade_Hex "
        .. "missing, Shout_PactOfTheBlade_Bind changed, Shout_Hexblade_Bind missing, Shout_WeaponBond changed.", 1, true),
        "client.log line")
end)

Test("the server finds the changes made and syncs nothing again", function()
    Ext.Events.SessionLoaded:Fire()
    AssertEq(syncs.Shout_PactOfTheBlade_Bind, 1, "no second sync")
    AssertTrue(string.find(Log("server.log"), "Spells: Shout_PactOfTheBlade as wanted, Shout_PactOfTheBlade_Hex missing, "
        .. "Shout_PactOfTheBlade_Bind as wanted, Shout_Hexblade_Bind missing, Shout_WeaponBond as wanted.", 1, true),
        "server.log line")
end)

Test("a table field is written as a new table", function()
    local before = bind.Requirements
    bind.Requirements = { { Not = true, Requirement = "Combat" } }
    Spells.Apply()
    AssertEq(#bind.Requirements, 0, "empty again")
    AssertTrue(bind.Requirements ~= Spells.Changes.Shout_PactOfTheBlade_Bind.Requirements, "not the shared table")
    AssertTrue(before ~= nil, "had a value")
end)
