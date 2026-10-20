-- The spell changes: free binds that work in combat too, new bind descriptions with an unbind warning, and no
-- cooldown on the pact weapon summons. The changes are made at run time (only these fields), so later game updates
-- of the other fields still reach the spells. Run-time changes are not saved and count only in this game process
-- (playbook knowledge\runtime_stats.md): the client applies them when the stats load, the server again on each
-- session load (on the host both share one stats instance; each remote player's game makes its own change).

local Spells = {}

-- Texts in Localization/English/bg3_pactandhexbladeqol.loca.xml; the warning in TooltipExtras/TooltipExtraTexts.lsx.
local PACT_DESCRIPTION = "h5598e728gfe9dg430cg83a0g24a3d7ab856e"
local HEX_DESCRIPTION = "h242e5354g7deeg40bdg93a6g1b4604797abf"
local UNBIND_WARNING = "875a0531-aa45-49ce-880c-e258c24db99c"

-- [entry] = { [field] = value }. A table value is written as a whole (Requirements is a table field).
Spells.Changes = {
    Shout_PactOfTheBlade = { Cooldown = "None" },
    Shout_PactOfTheBlade_Hex = { Cooldown = "None" },
    Shout_PactOfTheBlade_Bind = {
        Description = PACT_DESCRIPTION,
        ExtraDescription = "",
        TooltipPermanentWarnings = UNBIND_WARNING,
        Requirements = {},
        UseCosts = "",
    },
    Shout_Hexblade_Bind = {
        Description = HEX_DESCRIPTION,
        ExtraDescription = "",
        TooltipPermanentWarnings = UNBIND_WARNING,
        Requirements = {},
        UseCosts = "",
    },
    Shout_WeaponBond = { Requirements = {}, UseCosts = "" },
}

-- The order of the entries in the log.
Spells.Order = {
    "Shout_PactOfTheBlade", "Shout_PactOfTheBlade_Hex", "Shout_PactOfTheBlade_Bind", "Shout_Hexblade_Bind",
    "Shout_WeaponBond",
}

local function Same(current, wanted)
    if type(wanted) == "table" then
        return type(current) == "table" and #current == 0 and next(current) == nil
    end
    return current == wanted
end

--- Applies the changes. Writes only the fields that differ and syncs only the entries it changed. Returns a log text,
--- for example "Shout_PactOfTheBlade_Bind changed, Shout_WeaponBond as wanted, Shout_Hexblade_Bind missing".
function Spells.Apply()
    local parts = {}
    for _, name in ipairs(Spells.Order) do
        local stat = Ext.Stats.Get(name)
        if stat == nil then
            parts[#parts + 1] = name .. " missing"
        else
            local changed = false
            for field, value in pairs(Spells.Changes[name]) do
                if not Same(stat[field], value) then
                    stat[field] = type(value) == "table" and {} or value
                    changed = true
                end
            end
            if changed then
                stat:Sync()
            end
            parts[#parts + 1] = name .. (changed and " changed" or " as wanted")
        end
    end
    return table.concat(parts, ", ")
end

return Spells
