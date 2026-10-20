-- The weapon binds on the server: bind every equipped weapon on a bind spell, unbind on unequip, and the summoned
-- pact weapon.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }

local PACT_TAG = "be460271-537a-4443-a9b5-6c6c6a005ab3"

--- An Osiris GUID string: name and a 36-character UUID made from the number.
local function Guid(name, n)
    return string.format("%s_%08d-0000-0000-0000-%012d", name, n, n)
end

local Warlock = Guid("S_Player_Warlock", 1)
local Sword = Guid("WPN_Longsword", 2)
local Dagger = Guid("WPN_Dagger", 3)
local Bow = Guid("WPN_Longbow", 4)
local PactWeapon = Guid("WPN_PactOfTheBlade_Greatsword", 5)

-- [item] = { Equipped, Pact (tagged PACT_OF_THE_BLADE), Statuses }
local Items, Slots, Hexblade, PactInInventory
local Applied, Removed

local function Reset()
    Items = {
        [Sword] = { Equipped = true, Statuses = {} },
        [Dagger] = { Equipped = true, Statuses = {} },
        [Bow] = { Equipped = true, Statuses = {} },
        [PactWeapon] = { Equipped = false, Pact = true, Statuses = {} },
    }
    Slots = { ["Melee Main Weapon"] = Sword, ["Melee Offhand Weapon"] = Dagger, ["Ranged Main Weapon"] = Bow }
    Hexblade, PactInInventory = false, false
    Applied, Removed = {}, {}
end
Reset()

Osi.GetEquippedItem = function(character, slot)
    assert(character == Warlock, "GetEquippedItem: character")
    return Slots[slot]
end
Osi.HasActiveStatus = function(item, status)
    return Items[item].Statuses[status] and 1 or 0
end
Osi.ApplyStatus = function(item, status, duration)
    assert(duration == -1, "ApplyStatus: the bind lasts until it is removed")
    Items[item].Statuses[status] = true
    Applied[#Applied + 1] = { item, status }
end
Osi.RemoveStatus = function(item, status)
    Items[item].Statuses[status] = nil
    Removed[#Removed + 1] = { item, status }
end
Osi.IsEquipped = function(item)
    return Items[item].Equipped and 1 or 0
end
Osi.IsTagged = function(item, tag)
    return (Items[item].Pact and tag == PACT_TAG) and 1 or 0
end
Osi.GetItemByTagInInventory = function(tag, holder)
    assert(tag == PACT_TAG and holder == Warlock, "GetItemByTagInInventory arguments")
    return PactInInventory and PactWeapon or nil
end
Osi.HasPassive = function(character, passive)
    assert(character == Warlock and passive == "HexWarrior", "HasPassive arguments")
    return Hexblade and 1 or 0
end

Ext.Require("BootstrapServer.lua")

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_pactandhexbladeqol/server.log"] or ""
end

local function Cast(spell)
    Harness.Listeners["CastedSpell/5"](Warlock, spell, "Shout", "", 1)
end

local function Has(item, status)
    return Items[item].Statuses[status] == true
end

Test("the Pact of the Blade bind binds every equipped weapon", function()
    Reset()
    Items[Sword].Statuses.PACT_BLADE = true -- the game's own spell binds the main hand
    Cast("Shout_PactOfTheBlade_Bind")
    AssertTrue(Has(Dagger, "PACT_BLADE") and Has(Bow, "PACT_BLADE"), "off hand and ranged bound")
    AssertEq(#Applied, 2, "the main hand is not bound twice")
    AssertTrue(string.find(ServerLog(), "Shout_PactOfTheBlade_Bind by S_Player_Warlock: 2 more weapon(s) bound with PACT_BLADE.",
        1, true), "log")
end)

Test("the Hexblade bind binds every equipped weapon with its own status", function()
    Reset()
    Cast("Shout_Hexblade_Bind")
    AssertTrue(Has(Sword, "HEXBLADE_BIND") and Has(Dagger, "HEXBLADE_BIND") and Has(Bow, "HEXBLADE_BIND"), "all bound")
    AssertTrue(not Has(Sword, "PACT_BLADE"), "no Pact of the Blade status")
end)

Test("other spells and empty slots do nothing", function()
    Reset()
    Cast("Shout_Dash")
    AssertEq(#Applied, 0, "no bind")
    Slots = { ["Melee Main Weapon"] = Sword, ["Melee Offhand Weapon"] = Sword }
    Cast("Shout_PactOfTheBlade_Bind")
    AssertEq(#Applied, 1, "a weapon in two slots is bound once, empty slots are skipped")
end)

Test("an unequipped weapon loses its bind", function()
    Reset()
    Items[Dagger].Statuses.PACT_BLADE = true
    Items[Dagger].Equipped = false
    Harness.Listeners["Unequipped/2"](Dagger, Warlock)
    AssertTrue(not Has(Dagger, "PACT_BLADE"), "bind removed")
    AssertTrue(string.find(ServerLog(), "WPN_Dagger unequipped by S_Player_Warlock: bind removed.", 1, true), "log")
    Items[Bow].Equipped = false
    Harness.Listeners["Unequipped/2"](Bow, Warlock)
    AssertEq(#Removed, 1, "a weapon without a bind needs no removal")
end)

Test("a weapon that is still equipped keeps its bind", function()
    Reset()
    Items[Sword].Statuses.HEXBLADE_BIND = true
    Harness.Listeners["Unequipped/2"](Sword, Warlock)
    AssertTrue(Has(Sword, "HEXBLADE_BIND"), "kept")
end)

Test("the summoned pact weapon binds the other equipped weapons while it is equipped", function()
    Reset()
    PactInInventory = true
    Items[PactWeapon].Equipped = true
    Slots["Melee Main Weapon"] = PactWeapon
    Harness.Listeners["Equipped/2"](PactWeapon, Warlock)
    AssertTrue(Has(Dagger, "PACT_BLADE") and Has(Bow, "PACT_BLADE"), "the others are bound")
    AssertTrue(not Has(PactWeapon, "PACT_BLADE"), "the pact weapon itself is left to the game")
    AssertTrue(string.find(ServerLog(), "Pact weapon of S_Player_Warlock: 2 other weapon(s) bound with PACT_BLADE.", 1,
        true), "log")
end)

Test("with the Hexblade passive, the summoned weapon gives the Hexblade bind", function()
    Reset()
    PactInInventory, Hexblade = true, true
    Items[PactWeapon].Equipped = true
    Slots["Melee Main Weapon"] = PactWeapon
    Harness.Listeners["Equipped/2"](PactWeapon, Warlock)
    AssertTrue(Has(Dagger, "HEXBLADE_BIND") and Has(Bow, "HEXBLADE_BIND"), "Hexblade bind")
end)

Test("unequipping the summoned pact weapon unbinds the other weapons", function()
    Reset()
    PactInInventory = true
    Items[Dagger].Statuses.PACT_BLADE, Items[Bow].Statuses.HEXBLADE_BIND = true, true
    Harness.Listeners["Unequipped/2"](PactWeapon, Warlock)
    AssertTrue(not Has(Dagger, "PACT_BLADE") and not Has(Bow, "HEXBLADE_BIND"), "unbound")
    AssertTrue(string.find(ServerLog(), "Pact weapon unequipped by S_Player_Warlock: 2 weapon(s) unbound.", 1, true), "log")
end)

Test("equipping a weapon while the pact weapon is not equipped unbinds the equipped weapons", function()
    Reset()
    PactInInventory = true
    Items[Sword].Statuses.PACT_BLADE = true
    Harness.Listeners["Equipped/2"](Dagger, Warlock)
    AssertTrue(not Has(Sword, "PACT_BLADE"), "unbound, as in the example mod")
end)

Test("without a summoned pact weapon, equipping changes nothing", function()
    Reset()
    Items[Sword].Statuses.PACT_BLADE = true
    Harness.Listeners["Equipped/2"](Dagger, Warlock)
    AssertTrue(Has(Sword, "PACT_BLADE"), "kept")
    AssertEq(#Applied + #Removed, 0, "no change")
end)
