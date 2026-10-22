-- The data files fit the script: every text handle and the warning UUID that Spells.lua writes exist.

local SRC = MOD_LUA_ROOT .. "/../../../.."

local function Read(path)
    local text = READ_FILE(SRC .. "/" .. path)
    AssertTrue(text ~= nil, "missing file: src/" .. path)
    return text
end

local Spells = Ext.Require("Shared/Spells.lua")
local Binding = Ext.Require("Server/Binding.lua")
local Notice = Ext.Require("Server/Bg3DnDNotice.lua")
local loca = Read("Localization/English/bg3_pactandhexbladeqol.loca.xml")
local extras = Read("Public/bg3_pactandhexbladeqol/TooltipExtras/TooltipExtraTexts.lsx")
local statuses = Read("Public/bg3_pactandhexbladeqol/Stats/Generated/Data/Status_BOOST.txt")

local function Text(handle)
    return string.match(loca, 'contentuid="' .. handle .. '" version="%d+">([^<]+)<')
end

local function HasText(handle)
    local text = Text(handle)
    return text ~= nil and text ~= ""
end

--- The lines of a stats entry, up to the next entry.
local function Entry(text, name)
    local start = string.find(text, 'new entry "' .. name .. '"\n', 1, true)
    if start == nil then
        return nil
    end
    local next = string.find(text, "\nnew entry ", start + 1, true)
    return string.sub(text, start, next or #text)
end

Test("the mod's statuses exist, have texts and are not IsUnique", function()
    for _, name in ipairs({ Binding.ProficiencyStatus, Binding.PactWeaponMark }) do
        local entry = Entry(statuses, name)
        AssertTrue(entry ~= nil, name .. ": entry in Status_BOOST.txt")
        AssertTrue(string.find(entry, 'data "StatusType" "BOOST"', 1, true) ~= nil, name .. ": BOOST")
        AssertTrue(string.find(entry, "IgnoreResting", 1, true) ~= nil, name .. ": stays through a long rest")
        AssertTrue(string.find(entry, "IsUnique", 1, true) == nil, name .. ": one source may hold it on many weapons")
        for _, field in ipairs({ "DisplayName", "Description" }) do
            local handle = string.match(entry, 'data "' .. field .. '" "(h[%w]+);%d+"')
            AssertTrue(handle ~= nil and HasText(handle), name .. ": " .. field .. " has a text")
        end
    end
    AssertTrue(string.find(Entry(statuses, Binding.ProficiencyStatus), 'data "Boosts" "IntrinsicSourceProficiency()"', 1,
        true) ~= nil, "the proficiency boost")
end)

Test("the BG3DnD message has a short text", function()
    local text = Text(Notice.Message)
    AssertTrue(text ~= nil and text ~= "", "the message handle has a text")
    -- A message box shows about 231 characters; longer texts can crash the game.
    AssertTrue(#text <= 200, "at most 200 characters, has " .. #text)
end)

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
