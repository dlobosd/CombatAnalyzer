-- ===========================================================================
-- CLASSIC acquisition layer.
--
-- The .toc only loads this file when [AllowLoadGameType classic] matches
-- (Vanilla/Classic Era, TBC, Wrath, Cataclysm, Mists Classic, and any future
-- Classic progression client) so nothing here ever executes on Retail.
--
-- Verified for the current Classic clients (Interface 11509 / 20506 / 30405
-- / 40402 / 50504):
--   * COMBAT_LOG_EVENT_UNFILTERED + CombatLogGetCurrentEventInfo() exist and
--     return the same base argument layout as Retail for the subevents this
--     addon consumes (SPELL_DAMAGE, SWING_DAMAGE, SPELL_HEAL,
--     SPELL_CAST_SUCCESS, SPELL_INTERRUPT, UNIT_DIED). Classic inherited the
--     unified combat log format, it did not keep the pre-Cataclysm one.
--   * PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED, UnitGUID, UnitAffecting-
--     Combat and C_Timer.After all exist and behave the same as Retail.
--
-- Where Classic genuinely diverges (and why this file exists separately):
--   * Spell metadata lookups: Classic still uses the classic multi-return
--     GetSpellInfo(spellID) -> name, rank, icon, castTime, minRange,
--     maxRange, spellID. There is no C_Spell.GetSpellInfo on Classic. We
--     normalize this behind the same CL.GetSpellName/CL.GetSpellIcon
--     entry points used by Retail so shared code never branches on client.
--   * Aura inspection (future Buffs.lua work) only has the classic
--     UnitAura(unit, index, filter) API on Classic, not C_UnitAuras/
--     AuraUtil. Not implemented in v0.1, left as a note for when Buffs.lua
--     grows real uptime tracking.
-- ===========================================================================

CombatAnalyzer = CombatAnalyzer or {}
local CA = CombatAnalyzer
local CL = CA.CombatLog

function CL.GetSpellName(spellID)
    if not spellID or spellID == 0 then return nil end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        return name
    end
    return nil
end

function CL.GetSpellIcon(spellID)
    if not spellID or spellID == 0 then return nil end
    if GetSpellInfo then
        local _, _, icon = GetSpellInfo(spellID)
        return icon
    end
    return nil
end

function CL:InitClassic()
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
    self._classicFrame = f
end
