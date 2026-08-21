local CA = CombatAnalyzer
-- Buff/debuff uptime hooks can be expanded with real aura scanning later.
-- This module keeps the data model (combat.buffs / combat.debuffs) ready
-- for uptime tracking without implementing it yet, per V0.1 scope.
--
-- NOTE for whoever builds this out next: aura scanning is one of the areas
-- where Retail and Classic genuinely require different acquisition code
-- (Retail: C_UnitAuras.GetAuraDataByIndex / AuraUtil.ForEachAura; Classic:
-- the older UnitAura(unit, index, filter) multi-return call). That logic
-- belongs in CombatLog_Retail.lua / CombatLog_Classic.lua respectively,
-- normalized before it ever reaches CA:RecordAura below, exactly like
-- combat log events are normalized today.
function CA:RecordAura(kind, spellID, spellName, applied)
    if not self.current then return end
    local bucket = kind == "BUFF" and self.current.buffs or self.current.debuffs
    local a = bucket[spellID] or {id=spellID, name=spellName, applications=0, uptime=0, lastApplied=nil}
    if applied then
        a.applications = a.applications + 1
        a.lastApplied = GetTime()
    elseif a.lastApplied then
        a.uptime = a.uptime + (GetTime() - a.lastApplied)
        a.lastApplied = nil
    end
    bucket[spellID] = a
end
