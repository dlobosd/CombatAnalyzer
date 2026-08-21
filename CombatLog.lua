CombatAnalyzer = CombatAnalyzer or {}
local CA = CombatAnalyzer

-- ---------------------------------------------------------------------------
-- CA.CombatLog is the shared logic layer described in the architecture:
--
--   Core.lua
--      |
--      +-- CombatLog.lua            <- this file (client-agnostic)
--             |
--             +-- CombatLog_Retail.lua    (acquisition: Retail)
--             +-- CombatLog_Classic.lua   (acquisition: Classic)
--
-- Only one of CombatLog_Retail.lua / CombatLog_Classic.lua is ever loaded by
-- the client, chosen at the .toc level via [AllowLoadGameType]. Whichever one
-- loads is responsible for:
--   1. Registering exactly the events that exist on that client.
--   2. Pulling the raw combat log payload with the API that client provides.
--   3. Converting it into the NORMALIZED event table documented below and
--      handing it to CA.CombatLog:Dispatch().
--
-- Everything below this point never checks CA.IsRetail / CA.IsClassic. That
-- is the whole point of the shared layer: Damage.lua, Buffs.lua,
-- Interrupts.lua, Deaths.lua and Timeline.lua work purely off CA.current,
-- which is populated only through this file.
--
-- Normalized event table fields (nil where not applicable to the subEvent):
--   subEvent     - string, e.g. "SPELL_DAMAGE", "SWING_DAMAGE", "UNIT_DIED"
--   sourceGUID, sourceName, sourceFlags
--   destGUID, destName, destFlags
--   spellID, spellName, spellSchool
--   amount, overkill, critical
-- ---------------------------------------------------------------------------

CA.CombatLog = CA.CombatLog or {}
local CL = CA.CombatLog

function CL:IsPlayerGUID(guid)
    return guid ~= nil and guid == UnitGUID("player")
end

-- Selects and starts whichever acquisition layer was actually loaded for
-- this client. Exactly one of InitRetail/InitClassic will exist, because
-- the .toc only loads the matching file.
function CL:Init()
    if CA.IsRetail and self.InitRetail then
        self:InitRetail()
        CA:Debug("CombatLog acquisition layer: Retail")
    elseif CA.IsClassic and self.InitClassic then
        self:InitClassic()
        CA:Debug("CombatLog acquisition layer: Classic")
    else
        CA:Print("|cffff5555No matching CombatLog acquisition layer was loaded for this client.|r")
    end
end

-- Shared normalization/analysis logic. Called only with an already-
-- normalized event table (see header comment above).
function CL:Dispatch(evt)
    local player = UnitGUID("player")
    if not player then return end

    local sourceIsPlayer = evt.sourceGUID == player
    local destIsPlayer = evt.destGUID == player

    if sourceIsPlayer and not CA.inCombat then
        CA:StartCombat("COMBAT_LOG")
    end
    if not CA.inCombat then return end

    local sub = evt.subEvent

    if sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE"
        or sub == "RANGE_DAMAGE" or sub == "SWING_DAMAGE" then
        if sourceIsPlayer then
            local dmg = tonumber(evt.amount) or 0
            CA.current.damage = CA.current.damage + dmg
            local key = evt.spellID or 0
            local a = CA.current.abilities[key] or {name = evt.spellName or "Melee", id = key, damage = 0, casts = 0}
            a.damage = a.damage + dmg
            CA.current.abilities[key] = a
            CA:AddTimeline("DAMAGE", {spellID = key, spell = evt.spellName or "Melee", amount = dmg, target = evt.destName})
        end

    elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        if sourceIsPlayer then
            local heal = tonumber(evt.amount) or 0
            CA.current.healing = CA.current.healing + heal
            CA:AddTimeline("HEAL", {spellID = evt.spellID, spell = evt.spellName, amount = heal, target = evt.destName})
        end

    elseif sub == "SPELL_CAST_SUCCESS" then
        if sourceIsPlayer then
            local key = evt.spellID or 0
            local a = CA.current.abilities[key] or {name = evt.spellName or "Unknown", id = key, damage = 0, casts = 0}
            a.casts = a.casts + 1
            CA.current.abilities[key] = a
            CA.current.casts = CA.current.casts + 1
            CA:AddTimeline("CAST", {spellID = key, spell = evt.spellName})
        end

    elseif sub == "SPELL_INTERRUPT" then
        if sourceIsPlayer then
            CA.current.interrupts = CA.current.interrupts + 1
            CA:AddTimeline("INTERRUPT", {spellID = evt.spellID, spell = evt.spellName, target = evt.destName})
        end

    elseif sub == "UNIT_DIED" then
        if destIsPlayer then
            CA.current.deaths = CA.current.deaths + 1
            CA:AddTimeline("DEATH", {unit = evt.destName})
        end
    end
end
