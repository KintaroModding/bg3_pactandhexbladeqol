-- The weapon binds. The game's bind spells bind the main-hand weapon only; this module binds every equipped weapon
-- (shields excepted) when a bind spell is cast, removes the bind from a weapon when it is unequipped, and lets the
-- summoned pact weapon bind the other equipped weapons while it is equipped.
--
-- The bind statuses are applied without a source. They are IsUnique: a source can hold such a status on one target
-- only, and a new target takes it from the old one (playbook knowledge\boosts.md). The proficiency that PACT_BLADE gives
-- through its source (IntrinsicSourceProficiency) comes from the mod's own status PHQ_BIND_PROFICIENCY instead, which
-- is not IsUnique and gets the caster as source.

local ServerLog = Ext.Require("Server/ServerLog.lua")

local Binding = {}

Binding.PactStatus = "PACT_BLADE"
Binding.HexStatus = "HEXBLADE_BIND"
-- Proficiency with the weapon for the source of the status (Public/.../Stats/Generated/Data/Status_BOOST.txt).
Binding.ProficiencyStatus = "PHQ_BIND_PROFICIENCY"
-- Marks a bind that the summoned pact weapon gave; only these binds end when the pact weapon is unequipped. The game
-- saves statuses, so the mark survives a load.
Binding.PactWeaponMark = "PHQ_PACT_WEAPON_BIND"
-- The tag PACT_OF_THE_BLADE: "Weapon with this tag has been summoned by Pact of the Blade feature".
Binding.PactWeaponTag = "be460271-537a-4443-a9b5-6c6c6a005ab3"
-- With this passive, the summoned weapon gives the Hexblade bind.
Binding.HexbladePassive = "HexWarrior"
-- [bind spell] = the status it gives.
Binding.Spells = {
    Shout_PactOfTheBlade_Bind = Binding.PactStatus,
    Shout_Hexblade_Bind = Binding.HexStatus,
}
-- Every status a bind can leave on a weapon; an unbound weapon loses all of them.
Binding.AllStatuses = { Binding.PactStatus, Binding.HexStatus, Binding.ProficiencyStatus, Binding.PactWeaponMark }
Binding.Slots = { "Melee Main Weapon", "Melee Offhand Weapon", "Ranged Main Weapon", "Ranged Offhand Weapon" }

--- The UUID part of an Osiris GUID string (the last 36 characters).
local function Uuid(guid)
    return string.sub(guid, -36)
end

--- A short name for the log: the GUID string without its UUID, or the UUID when there is no name.
local function Short(guid)
    local name = string.sub(guid, 1, -38)
    return name ~= "" and name or guid
end

local function Has(item, status)
    return Osi.HasActiveStatus(item, status) == 1
end

--- The equipped weapons of a character, each one once, without the equipped shield and the item `except` (a GUID
--- string or nil).
local function EquippedWeapons(character, except)
    local weapons, seen = {}, {}
    if except ~= nil then
        seen[Uuid(except)] = true
    end
    local shield = Osi.GetEquippedShield(character)
    if shield ~= nil then
        seen[Uuid(shield)] = true
    end
    for _, slot in ipairs(Binding.Slots) do
        local item = Osi.GetEquippedItem(character, slot)
        if item ~= nil and not seen[Uuid(item)] then
            seen[Uuid(item)] = true
            weapons[#weapons + 1] = item
        end
    end
    return weapons
end

--- Gives a weapon the bind status when it does not have it, and the proficiency for `character`. Returns true when
--- the weapon changed.
local function Bind(item, status, character)
    local changed = false
    if not Has(item, status) then
        -- The story PROC with three arguments: Force 0, no source.
        Osi.ApplyStatus(item, status, -1)
        changed = true
    end
    if not Has(item, Binding.ProficiencyStatus) then
        Osi.ApplyStatus(item, Binding.ProficiencyStatus, -1, 0, character)
        changed = true
    end
    return changed
end

--- Removes every bind status. Returns true when the weapon had one.
local function Unbind(item)
    local removed = false
    for _, status in ipairs(Binding.AllStatuses) do
        if Has(item, status) then
            Osi.RemoveStatus(item, status)
            removed = true
        end
    end
    return removed
end

--- A bind spell binds every equipped weapon. The game's own spell has bound the main-hand weapon already; the status
--- check skips it. A weapon that the summoned pact weapon bound keeps this bind from now on.
function Binding.OnCast(character, spell)
    local status = Binding.Spells[spell]
    if status == nil then
        return
    end
    local count = 0
    for _, item in ipairs(EquippedWeapons(character)) do
        local changed = Bind(item, status, character)
        if Has(item, Binding.PactWeaponMark) then
            Osi.RemoveStatus(item, Binding.PactWeaponMark)
            changed = true
        end
        if changed then
            count = count + 1
        end
    end
    ServerLog.Add(string.format("%s by %s: %d weapon(s) changed with %s.", spell, Short(character), count, status))
end

--- The weapons that the summoned pact weapon bound lose their bind; the binds of the bind spells stay. Returns the
--- number of weapons unbound.
local function UnbindPactWeaponBinds(weapons)
    local count = 0
    for _, item in ipairs(weapons) do
        if Has(item, Binding.PactWeaponMark) and Unbind(item) then
            count = count + 1
        end
    end
    return count
end

--- An unequipped weapon loses its bind. When the summoned pact weapon is unequipped, the weapons it bound lose theirs.
function Binding.OnUnequipped(item, character)
    if Osi.IsEquipped(item) == 1 then
        return
    end
    if Osi.IsTagged(item, Binding.PactWeaponTag) == 1 then
        local count = UnbindPactWeaponBinds(EquippedWeapons(character, item))
        if count > 0 then
            ServerLog.Add(string.format("Pact weapon unequipped by %s: %d weapon(s) unbound.", Short(character), count))
        end
    elseif Unbind(item) then
        ServerLog.Add(string.format("%s unequipped by %s: bind removed.", Short(item), Short(character)))
    end
end

--- While the summoned pact weapon is equipped, it binds the other equipped weapons that have no bind yet (the
--- Hexblade bind with the Hexblade passive), and marks these binds. When the character has a summoned pact weapon that
--- is not equipped, the marked binds end. Binds of the bind spells stay in both cases.
function Binding.OnEquipped(_, character)
    local pactWeapon = Osi.GetItemByTagInInventory(Binding.PactWeaponTag, character)
    if pactWeapon == nil then
        return
    end
    if Osi.IsEquipped(pactWeapon) == 1 then
        local status = Osi.HasPassive(character, Binding.HexbladePassive) == 1 and Binding.HexStatus
            or Binding.PactStatus
        local count = 0
        for _, item in ipairs(EquippedWeapons(character, pactWeapon)) do
            if not Has(item, Binding.PactStatus) and not Has(item, Binding.HexStatus) then
                Bind(item, status, character)
                Osi.ApplyStatus(item, Binding.PactWeaponMark, -1)
                count = count + 1
            end
        end
        if count > 0 then
            ServerLog.Add(string.format("Pact weapon of %s: %d other weapon(s) bound with %s.", Short(character), count,
                status))
        end
    else
        local count = UnbindPactWeaponBinds(EquippedWeapons(character))
        if count > 0 then
            ServerLog.Add(string.format("Pact weapon of %s not equipped: %d weapon(s) unbound.", Short(character),
                count))
        end
    end
end

function Binding.Init()
    Ext.Osiris.RegisterListener("CastedSpell", 5, "after", function(caster, spell, _, _, _)
        Binding.OnCast(caster, spell)
    end)
    Ext.Osiris.RegisterListener("Unequipped", 2, "after", Binding.OnUnequipped)
    Ext.Osiris.RegisterListener("Equipped", 2, "after", Binding.OnEquipped)
end

return Binding
