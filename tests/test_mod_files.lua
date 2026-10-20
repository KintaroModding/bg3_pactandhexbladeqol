-- The data files fit the script: every text handle and the warning UUID that Spells.lua writes exist.

local SRC = MOD_LUA_ROOT .. "/../../../.."

local function Read(path)
    local text = READ_FILE(SRC .. "/" .. path)
    AssertTrue(text ~= nil, "missing file: src/" .. path)
    return text
end

local Spells = Ext.Require("Shared/Spells.lua")
local loca = Read("Localization/English/bg3_pactandhexbladeqol.loca.xml")
local extras = Read("Public/bg3_pactandhexbladeqol/TooltipExtras/TooltipExtraTexts.lsx")

local function HasText(handle)
    local text = string.match(loca, 'contentuid="' .. handle .. '" version="%d+">([^<]+)<')
    return text ~= nil and text ~= ""
end

Test("every new description has a text", function()
    for name, fields in pairs(Spells.Changes) do
        if fields.Description then
            AssertTrue(HasText(fields.Description), name .. ": the description handle has a text")
        end
    end
end)

Test("the unbind warning exists in TooltipExtraTexts.lsx and has a text", function()
    local uuid = Spells.Changes.Shout_PactOfTheBlade_Bind.TooltipPermanentWarnings
    AssertEq(Spells.Changes.Shout_Hexblade_Bind.TooltipPermanentWarnings, uuid, "both binds show the same warning")
    -- "-" is a pattern character in Lua, so the UUID is escaped.
    local handle = string.match(extras, 'handle="(h[%w]+)" version="%d+"/>%s*<attribute id="UUID" type="guid" value="'
        .. uuid:gsub("%-", "%%-") .. '"')
    AssertTrue(handle ~= nil, "TooltipExtraTexts entry with this UUID")
    AssertTrue(HasText(handle), "the warning handle has a text")
end)
