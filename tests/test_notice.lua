-- The message box with DnD 5.5e All-in-One BEYOND: once per load, a moment after gameplay starts, for the host only.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }

local BG3DND = "897914ef-5c96-053c-44af-0be823f895fe"
local HOST = "S_Player_Warlock_00000001-0000-0000-0000-000000000001"
local boxes = {}

Harness.HostCharacter = HOST
Harness.Loca.h7c28a4aeg45c5g404bgadd6g49d421aa2f6a = "Use the BEYOND version."
Osi.OpenMessageBox = function(character, message)
    boxes[#boxes + 1] = { character, message }
end

Ext.Require("BootstrapServer.lua")

local function GameplayStarted()
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
end

Test("without DnD 5.5e BEYOND, no message", function()
    GameplayStarted()
    Harness.RunTimers()
    AssertEq(#boxes, 0, "no box")
end)

Test("with DnD 5.5e BEYOND, the host gets the message once, after a delay", function()
    Harness.LoadedMods[BG3DND] = true
    GameplayStarted()
    AssertEq(#boxes, 0, "not at once")
    Harness.RunTimers()
    AssertEq(#boxes, 1, "one box")
    AssertEq(boxes[1][1], HOST, "to the host")
    AssertEq(boxes[1][2], "Use the BEYOND version.", "the translated text")
    GameplayStarted()
    Harness.RunTimers()
    AssertEq(#boxes, 1, "not again in the same load (level change)")
    AssertTrue(string.find(Harness.Files["bg3_pactandhexbladeqol/server.log"] or "",
        "DnD 5.5e All-in-One BEYOND is active", 1, true), "log")
end)
