CombatAnalyzer = CombatAnalyzer or {}
local CA = CombatAnalyzer

CA.version = "0.1.0"
CA.inCombat = false
CA.current = nil
CA.history = {}
CA.debugEnabled = false

-- ---------------------------------------------------------------------------
-- Client / flavor detection
--
-- WOW_PROJECT_ID (and the WOW_PROJECT_* constants it's compared against) is
-- an official Blizzard global, set by the client itself before any addon
-- code runs, and is the documented, supported way for addons to tell Retail
-- apart from any Classic client. We deliberately do NOT special-case every
-- individual Classic expansion (Vanilla/TBC/Wrath/Cata/Mists/...): for the
-- purposes of CombatAnalyzer's data-acquisition layer, everything that is
-- not WOW_PROJECT_MAINLINE is treated as "Classic", because the combat log
-- API surface CombatAnalyzer depends on is identical across all of them.
-- This also matches the addon's file layout: exactly two acquisition
-- implementations (Retail / Classic), never one per expansion.
-- ---------------------------------------------------------------------------
local function DetectClient()
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        CA.IsRetail = true
        CA.IsClassic = false
        CA.ClientFlavor = "Retail"
    else
        CA.IsRetail = false
        CA.IsClassic = true
        CA.ClientFlavor = "Classic"
    end

    -- Kept for diagnostics/UI only; never branch analysis logic on this.
    local version, build, date, tocversion = GetBuildInfo()
    CA.BuildInfo = { version = version, build = build, date = date, tocversion = tocversion }
end
DetectClient()

function CA:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Combat Analyzer|r: " .. tostring(msg))
end

function CA:Debug(msg)
    if self.debugEnabled then self:Print("|cffaaaaaa[DEBUG]|r " .. tostring(msg)) end
end

-- ---------------------------------------------------------------------------
-- Normalized combat data model. Every field here is filled exclusively by
-- the shared CombatLog.lua dispatcher, which itself only receives data that
-- was already converted to this common shape by whichever acquisition layer
-- (Retail or Classic) is active. Damage.lua, Buffs.lua, Interrupts.lua,
-- Deaths.lua, Timeline.lua and UI.lua only ever read this structure.
-- ---------------------------------------------------------------------------
function CA:NewCombat()
    local c = {
        start = GetTime(),
        finish = nil,
        duration = 0,
        damage = 0,
        healing = 0,
        casts = 0,
        interrupts = 0,
        deaths = 0,
        abilities = {},
        buffs = {},
        debuffs = {},
        timeline = {},
    }
    self.current = c
    return c
end

function CA:AddTimeline(event, data)
    if not self.current then return end
    data = data or {}
    data.t = GetTime() - self.current.start
    data.event = event
    table.insert(self.current.timeline, data)
end

function CA:StartCombat(reason)
    if self.inCombat then return end
    self.inCombat = true
    self:NewCombat()
    self:AddTimeline("COMBAT_START", {reason = reason})
    self:Print("Combat started.")
end

function CA:EndCombat(reason)
    if not self.inCombat or not self.current then return end
    self.current.finish = GetTime()
    self.current.duration = self.current.finish - self.current.start
    self:AddTimeline("COMBAT_END", {reason = reason})
    table.insert(self.history, 1, self.current)
    while #self.history > 20 do table.remove(self.history) end
    self.inCombat = false
    self:Print(string.format("Combat ended: %.1fs | DPS %.1f | Damage %d",
        self.current.duration,
        self.current.duration > 0 and self.current.damage / self.current.duration or 0,
        self.current.damage))
    self.current = nil
end

function CA:Reset()
    for i = #self.history, 1, -1 do
        self.history[i] = nil
    end
    self.current = nil
    self.inCombat = false
    self:Print("Combat history reset.")
end

SLASH_COMBATANALYZER1 = "/ca"
SlashCmdList.COMBATANALYZER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        CA:Reset()
    elseif msg == "debug" then
        CA.debugEnabled = not CA.debugEnabled
        CA:Print("Debug: " .. (CA.debugEnabled and "ON" or "OFF"))
    elseif msg == "version" then
        CA:Print(string.format("v%s | Client: %s | Build %s (%s)",
            CA.version, CA.ClientFlavor, CA.BuildInfo.build, CA.BuildInfo.version))
    else
        CA:ToggleUI()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        CombatAnalyzerDB = CombatAnalyzerDB or {history = {}}
        CombatAnalyzerDB.history = CombatAnalyzerDB.history or {}
        CA.history = CombatAnalyzerDB.history

        -- Select and start the data-acquisition layer that matches this
        -- client. CA.CombatLog.Init dispatches to InitRetail/InitClassic,
        -- whichever one actually got loaded by the .toc for this client.
        if CA.CombatLog and CA.CombatLog.Init then
            CA.CombatLog:Init()
        end

        CA:Print(string.format("Loaded (%s). Type /ca", CA.ClientFlavor))
    elseif event == "PLAYER_REGEN_DISABLED" then
        CA:StartCombat("PLAYER_REGEN_DISABLED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(3, function()
            if not UnitAffectingCombat("player") then
                CA:EndCombat("PLAYER_REGEN_ENABLED")
            end
        end)
    end
end)
