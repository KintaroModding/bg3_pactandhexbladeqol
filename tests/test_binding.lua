-- The weapon binds on the server: bind every equipped weapon on a bind spell, the proficiency, unbind on unequip, and
-- the summoned pact weapon with its marked binds.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }

local PACT_TAG = "be460271-537a-4443-a9b5-6c6c6a005ab3"
local PROFICIENCY = "PHQ_BIND_PROFICIENCY"
local MARK = "PHQ_PACT_WEAPON_BIND"

--- An Osiris GUID string: name and a 36-character UUID made from the number.
local function Guid(name, n)
    return string.format("%s_%08d-0000-0000-0000-%012d", name, n, n)
end

local Warlock = Guid("S_Player_Warlock", 1)
local Sword = Guid("WPN_Longsword", 2)
local Dagger = Guid("WPN_Dagger", 3)
local Bow = Guid("WPN_Longbow", 4)
local PactWeapon = Guid("WPN_PactOfTheBlade_Greatsword", 5)
local Shield = Guid("ARM_Shield", 6)
local Ring = Guid("UNI_Ring", 7)

-- [item] = { Equipped, Pact (tagged PACT_OF_THE_BLADE), Statuses = { [status] = duration } }
local Items, Slots, EquippedShield, Hexblade, PactInInventory
local Applied, Removed

local function Reset()
    Items = {
        [Sword] = { Equipped = true, Statuses = {} },
        [Dagger] = { Equipped = true, Statuses = {} },
        [Bow] = { Equipped = true, Statuses = {} },
        [PactWeapon] = { Equipped = false, Pact = true, Statuses = {} },
        [Shield] = { Equipped = false, Statuses = {} },
        [Ring] = { Equipped = true, Statuses = {} },
    }
    Slots = { ["Melee Main Weapon"] = Sword, ["Melee Offhand Weapon"] = Dagger, ["Ranged Main Weapon"] = Bow }
    EquippedShield, Hexblade, PactInInventory = nil, false, false
    Applied, Removed = {}, {}
end
Reset()

Osi.GetEquippedItem = function(character, slot)
    assert(character == Warlock, "GetEquippedItem: character")
    return Slots[slot]
end
Osi.GetEquippedShield = function(character)
    assert(character == Warlock, "GetEquippedShield: character")
    return EquippedShield
end
Osi.HasActiveStatus = function(item, status)
    return Items[item].Statuses[status] and 1 or 0
end
-- The bind statuses are IsUnique: a source holds one on one target only, so the mod applies them without a source (the
-- three-argument PROC). Only the proficiency needs the caster as source.
Osi.ApplyStatus = function(item, status, duration, force, source)
    assert(duration == -1, "ApplyStatus: until removed")
    if status == PROFICIENCY then
        assert(force == 0 and source == Warlock, "ApplyStatus: the proficiency has the caster as source")
    else
        assert(force == nil and source == nil, "ApplyStatus: without a source")
    end
    Items[item].Statuses[status] = duration
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
    return Items[item].Statuses[status] ~= nil
end

--- The number of statuses applied, without the proficiency.
local function AppliedBinds()
    local count = 0
    for _, entry in ipairs(Applied) do
        if entry[2] ~= PROFICIENCY then
            count = count + 1
        end
    end
    return count
end

--- A summoned pact weapon in the main hand.
local function EquipPactWeapon()
    PactInInventory = true
    Items[PactWeapon].Equipped = true
    Slots["Melee Main Weapon"] = PactWeapon
    Harness.Listeners["Equipped/2"](PactWeapon, Warlock)
end

Test("the Pact of the Blade bind binds every equipped weapon", function()
    Reset()
    Items[Sword].Statuses.PACT_BLADE = -1 -- the game's own spell binds the main hand
    Cast("Shout_PactOfTheBlade_Bind")
    AssertTrue(Has(Dagger, "PACT_BLADE") and Has(Bow, "PACT_BLADE"), "off hand and ranged bound")
    AssertEq(AppliedBinds(), 2, "the main hand is not bound twice")
    AssertTrue(string.find(ServerLog(), "Shout_PactOfTheBlade_Bind by S_Player_Warlock: 3 weapon(s) changed with "
        .. "PACT_BLADE.", 1, true), "log")
end)

Test("every bound weapon gives the caster proficiency", function()
    Reset()
    Items[Sword].Statuses.PACT_BLADE = -1
    Cast("Shout_PactOfTheBlade_Bind")
    for _, item in ipairs({ Sword, Dagger, Bow }) do
        AssertTrue(Has(item, PROFICIENCY), "proficiency")
    end
    Applied = {}
    Cast("Shout_PactOfTheBlade_Bind")
    AssertEq(#Applied, 0, "a second cast changes nothing")
    AssertTrue(string.find(ServerLog(), "0 weapon(s) changed with PACT_BLADE.", 1, true), "log")
end)

Test("the Hexblade bind binds every equipped weapon with its own status", function()
    Reset()
    Cast("Shout_Hexblade_Bind")
    AssertTrue(Has(Sword, "HEXBLADE_BIND") and Has(Dagger, "HEXBLADE_BIND") and Has(Bow, "HEXBLADE_BIND"), "all bound")
    AssertTrue(Has(Dagger, PROFICIENCY), "proficiency")
    AssertTrue(not Has(Sword, "PACT_BLADE"), "no Pact of the Blade status")
end)

Test("a shield is not bound", function()
    Reset()
    EquippedShield = Shield
    Items[Shield].Equipped = true
    Slots["Melee Offhand Weapon"] = Shield
    Cast("Shout_PactOfTheBlade_Bind")
    AssertTrue(not Has(Shield, "PACT_BLADE") and not Has(Shield, PROFICIENCY), "shield left alone")
    AssertTrue(Has(Bow, "PACT_BLADE"), "the bow is bound")
end)

Test("other spells and empty slots do nothing", function()
    Reset()
    Cast("Shout_Dash")
    AssertEq(#Applied, 0, "no bind")
    Slots = { ["Melee Main Weapon"] = Sword, ["Melee Offhand Weapon"] = Sword }
    Cast("Shout_PactOfTheBlade_Bind")
    AssertEq(AppliedBinds(), 1, "a weapon in two slots is bound once, empty slots are skipped")
end)

Test("an unequipped weapon loses its bind and the proficiency", function()
    Reset()
    Cast("Shout_PactOfTheBlade_Bind")
    Items[Dagger].Equipped = false
    Removed = {}
    Harness.Listeners["Unequipped/2"](Dagger, Warlock)
    AssertTrue(not Has(Dagger, "PACT_BLADE") and not Has(Dagger, PROFICIENCY), "both removed")
    AssertTrue(string.find(ServerLog(), "WPN_Dagger unequipped by S_Player_Warlock: bind removed.", 1, true), "log")
    AssertEq(#Removed, 2, "bind and proficiency")
    Reset()
    Items[Bow].Equipped = false
    Harness.Listeners["Unequipped/2"](Bow, Warlock)
    AssertEq(#Removed, 0, "a weapon without a bind needs no removal")
end)

Test("a weapon that is still equipped keeps its bind", function()
    Reset()
    Items[Sword].Statuses.HEXBLADE_BIND = -1
    Harness.Listeners["Unequipped/2"](Sword, Warlock)
    AssertTrue(Has(Sword, "HEXBLADE_BIND"), "kept")
end)

Test("the summoned pact weapon binds and marks the other equipped weapons while it is equipped", function()
    Reset()
    EquipPactWeapon()
    for _, item in ipairs({ Dagger, Bow }) do
        AssertTrue(Has(item, "PACT_BLADE") and Has(item, MARK) and Has(item, PROFICIENCY), "bound, marked, proficient")
    end
    AssertTrue(not Has(PactWeapon, "PACT_BLADE"), "the pact weapon itself is left to the game")
    AssertTrue(string.find(ServerLog(), "Pact weapon of S_Player_Warlock: 2 other weapon(s) bound with PACT_BLADE.", 1,
        true), "log")
end)

Test("the summoned pact weapon leaves weapons alone that a bind spell bound", function()
    Reset()
    Cast("Shout_PactOfTheBlade_Bind")
    Applied = {}
    Slots["Ranged Main Weapon"] = nil
    EquipPactWeapon()
    AssertEq(#Applied, 0, "nothing applied")
    AssertTrue(not Has(Dagger, MARK) and Has(Dagger, "PACT_BLADE"), "the spell's bind stays as it was")
end)

Test("with the Hexblade passive, the summoned weapon gives the Hexblade bind", function()
    Reset()
    Hexblade = true
    EquipPactWeapon()
    AssertTrue(Has(Dagger, "HEXBLADE_BIND") and Has(Bow, "HEXBLADE_BIND"), "Hexblade bind")
end)

Test("unequipping the summoned pact weapon ends only the binds it gave", function()
    Reset()
    EquipPactWeapon()
    Items[Bow].Statuses = {}
    Cast("Shout_PactOfTheBlade_Bind") -- the bow gets a spell bind; the dagger's marked bind becomes a spell bind
    AssertTrue(not Has(Dagger, MARK), "a bind spell turns the marked bind into its own")
    Items[Dagger].Statuses = { PACT_BLADE = -1, [MARK] = -1, [PROFICIENCY] = -1 }
    Items[PactWeapon].Equipped = false
    Slots["Melee Main Weapon"] = Sword
    Harness.Listeners["Unequipped/2"](PactWeapon, Warlock)
    AssertTrue(not Has(Dagger, "PACT_BLADE") and not Has(Dagger, MARK) and not Has(Dagger, PROFICIENCY),
        "the marked bind ended")
    AssertTrue(Has(Bow, "PACT_BLADE"), "the spell's bind stays")
    AssertTrue(string.find(ServerLog(), "Pact weapon unequipped by S_Player_Warlock: 1 weapon(s) unbound.", 1, true), "log")
end)

Test("a gear change with the pact weapon in the bag keeps the binds of the bind spells", function()
    Reset()
    PactInInventory = true
    Cast("Shout_PactOfTheBlade_Bind")
    Items[Bow].Statuses[MARK] = -1 -- a bind that the pact weapon gave earlier
    Harness.Listeners["Equipped/2"](Ring, Warlock)
    AssertTrue(Has(Sword, "PACT_BLADE") and Has(Dagger, "PACT_BLADE"), "spell binds kept")
    AssertTrue(not Has(Bow, "PACT_BLADE"), "the marked bind ended")
    AssertTrue(string.find(ServerLog(), "Pact weapon of S_Player_Warlock not equipped: 1 weapon(s) unbound.", 1, true),
        "log")
end)

Test("without a summoned pact weapon, equipping changes nothing", function()
    Reset()
    Items[Sword].Statuses.PACT_BLADE = -1
    Harness.Listeners["Equipped/2"](Dagger, Warlock)
    AssertTrue(Has(Sword, "PACT_BLADE"), "kept")
    AssertEq(#Applied + #Removed, 0, "no change")
end)
