-- DnD 5.5e All-in-One BEYOND (BG3DnD) turns the Pact of the Blade bind into a container with four new spells, which
-- this mod does not know, so its bind binds no extra weapon there. With BG3DnD active, the host gets a message box once
-- per load that names the mod made for BG3DnD (Pact and Hexblade QoL - DnD 5.5e BEYOND).

local ServerLog = Ext.Require("Server/ServerLog.lua")

local Notice = {}

Notice.Bg3DnDModuleUUID = "897914ef-5c96-053c-44af-0be823f895fe"
-- The text, in Localization/English/bg3_pactandhexbladeqol.loca.xml. A message box shows about 231 characters at most,
-- and longer texts can crash the game (Script Extender issue 248), so the text stays short.
Notice.Message = "h7c28a4aeg45c5g404bgadd6g49d421aa2f6a"
-- A message box opened right at LevelGameplayStarted does not show; other mods wait a few ticks.
Notice.DelayMs = 3000

-- Both Lua states start again on every save load, so the box shows once per load.
local shown = false

function Notice.Bg3DnDLoaded()
    local ok, loaded = pcall(Ext.Mod.IsModLoaded, Notice.Bg3DnDModuleUUID)
    return ok and loaded == true
end

function Notice.Show()
    local ok, host = pcall(Osi.GetHostCharacter)
    if not ok or host == nil then
        return
    end
    Osi.OpenMessageBox(host, Ext.Loca.GetTranslatedString(Notice.Message))
end

function Notice.OnGameplayStarted()
    if shown or not Notice.Bg3DnDLoaded() then
        return
    end
    shown = true
    ServerLog.Add("DnD 5.5e All-in-One BEYOND is active: its bind spells are unknown to this mod. Message shown.")
    Ext.Timer.WaitFor(Notice.DelayMs, Notice.Show)
end

function Notice.Init()
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(_, _)
        Notice.OnGameplayStarted()
    end)
end

return Notice
