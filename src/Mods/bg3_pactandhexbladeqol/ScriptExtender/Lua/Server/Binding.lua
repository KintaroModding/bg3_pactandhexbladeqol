-- The weapon binds. The game's bind spells bind the main-hand weapon only; this module binds every equipped weapon
-- when a bind spell is cast, removes the bind from a weapon when it is unequipped, and lets the summoned pact weapon
-- bind the other equipped weapons while it is equipped.

local ServerLog = Ext.Require("Server/ServerLog.lua")

local Binding = {}

Binding.PactStatus = "PACT_BLADE"
Binding.HexStatus = "HEXBLADE_BIND"
-- The tag PACT_OF_THE_BLADE: "Weapon with this tag has been summoned by Pact of the Blade feature".
Binding.PactWeaponTag = "be460271-537a-4443-a9b5-6c6c6a005ab3"
-- With this passive, the summoned weapon gives the Hexblade bind.
Binding.HexbladePassive = "HexWarrior"
-- [bind spell] = the status it gives.
Binding.Spells = {
    Shout_PactOfTheBlade_Bind = Binding.PactStatus,
    Shout_Hexblade_Bind = Binding.HexStatus,
}
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

--- The equipped weapons of a character, each one once, without the item `except` (a GUID string or nil).
local function EquippedWeapons(character, except)
    local weapons, seen = {}, {}
    if except ~= nil then
        seen[Uuid(except)] = true
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

--- Gives the bind status when the weapon does not have it. Returns true when given.
local function Bind(item, status)
    if Osi.HasActiveStatus(item, status) == 1 then
        return false
    end
    Osi.ApplyStatus(item, status, -1)
    return true
end

--- Removes both bind statuses. Returns true when the weapon had one.
local function Unbind(item)
    local removed = false
    for _, status in ipairs({ Binding.PactStatus, Binding.HexStatus }) do
        if Osi.HasActiveStatus(item, status) == 1 then
            Osi.RemoveStatus(item, status)
            removed = true
        end
    end
    return removed
end

local function BindAll(weapons, status)
    local count = 0
    for _, item in ipairs(weapons) do
        if Bind(item, status) then
            count = count + 1
        end
    end
    return count
end

local function UnbindAll(weapons)
    local count = 0
    for _, item in ipairs(weapons) do
        if Unbind(item) then
            count = count + 1
        end
    end
    return count
end

--- A bind spell binds every equipped weapon. The game's own spell has bound the main-hand weapon already; the
--- status check skips it.
function Binding.OnCast(character, spell)
    local status = Binding.Spells[spell]
    if status == nil then
        return
    end
    local count = BindAll(EquippedWeapons(character), status)
    ServerLog.Add(string.format("%s by %s: %d more weapon(s) bound with %s.", spell, Short(character), count, status))
end

--- An unequipped weapon loses its bind. When the summoned pact weapon is unequipped, the weapons it bound lose theirs.
function Binding.OnUnequipped(item, character)
    if Osi.IsEquipped(item) == 1 then
        return
    end
    if Osi.IsTagged(item, Binding.PactWeaponTag) == 1 then
        local count = UnbindAll(EquippedWeapons(character, item))
        if count > 0 then
            ServerLog.Add(string.format("Pact weapon unequipped by %s: %d weapon(s) unbound.", Short(character), count))
        end
    elseif Unbind(item) then
        ServerLog.Add(string.format("%s unequipped by %s: bind removed.", Short(item), Short(character)))
    end
end

--- While the summoned pact weapon is equipped, it binds the other equipped weapons (the Hexblade bind with the
--- Hexblade passive). When the character has a summoned pact weapon that is not equipped, the equipped weapons lose
--- their binds.
function Binding.OnEquipped(_, character)
    local pactWeapon = Osi.GetItemByTagInInventory(Binding.PactWeaponTag, character)
    if pactWeapon == nil then
        return
    end
    if Osi.IsEquipped(pactWeapon) == 1 then
        local status = Osi.HasPassive(character, Binding.HexbladePassive) == 1 and Binding.HexStatus
            or Binding.PactStatus
        local count = BindAll(EquippedWeapons(character, pactWeapon), status)
        if count > 0 then
            ServerLog.Add(string.format("Pact weapon of %s: %d other weapon(s) bound with %s.", Short(character), count,
                status))
        end
    else
        local count = UnbindAll(EquippedWeapons(character))
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
