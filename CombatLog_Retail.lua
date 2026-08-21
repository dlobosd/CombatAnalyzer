-- ===========================================================================
-- RETAIL acquisition layer.
--
-- The .toc only loads this file when [AllowLoadGameType mainline] matches,
-- so nothing here ever executes on a Classic client.
--
-- Verified for current Retail (Interface 120100):
--   * COMBAT_LOG_EVENT_UNFILTERED + CombatLogGetCurrentEventInfo() exist and
--     return the same base argument layout (timestamp, subevent, hideCaster,
--     sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID,
--     destName, destFlags, destRaidFlags, ...) that Classic uses. This part
--     of the acquisition step is genuinely identical across both clients.
--   * PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED, UnitGUID, UnitAffecting-
--     Combat and C_Timer.After all exist and behave the same as Classic.
--
-- Where Retail genuinely diverges (and why this file exists separately even
-- though the event parsing above is shared logic):
--   * Spell metadata lookups: Retail has deprecated the old multi-return
--     GetSpellInfo() in favor of C_Spell.GetSpellInfo(spellID), which returns
--     a table {name, iconID, castTime, minRange, maxRange, spellID}. We
--     expose a normalized CL.GetSpellName/CL.GetSpellIcon here so later
--     modules never need to know which API produced the value.
--   * Aura inspection (used by future Buffs.lua work) uses C_UnitAuras /
--     AuraUtil on Retail, vs. the older UnitAura(unit, index, filter) on
--     Classic. Not implemented in v0.1 (analysis systems are out of scope
--     for this milestone), but the acquisition layer is the correct place
--     for that divergence to live once it's built.
-- ===========================================================================

CombatAnalyzer = CombatAnalyzer or {}
local CA = CombatAnalyzer
local CL = CA.CombatLog

function CL.GetSpellName(spellID)
    if not spellID or spellID == 0 then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name or nil
    end
    -- Defensive fallback in case a future Retail build still exposes the
    -- legacy global for a transition period.
    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
    return nil
end

function CL.GetSpellIcon(spellID)
    if not spellID or spellID == 0 then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.iconID or nil
    end
    return nil
end

function CL:InitRetail()
    local f = CreateFrame("Frame")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f:SetScript("OnEvent", function()
        local timestamp, subEvent, _, sourceGUID, sourceName, sourceFlags,
              _, destGUID, destName, destFlags, _, spellID, spellName,
              spellSchool, amount, overkill = CombatLogGetCurrentEventInfo()

        CL:Dispatch({
            subEvent = subEvent,
            sourceGUID = sourceGUID,
            sourceName = sourceName,
            sourceFlags = sourceFlags,
            destGUID = destGUID,
            destName = destName,
            destFlags = destFlags,
            spellID = spellID,
            spellName = spellName,
            spellSchool = spellSchool,
            amount = amount,
            overkill = overkill,
        })
    end)
    self._retailFrame = f
end
