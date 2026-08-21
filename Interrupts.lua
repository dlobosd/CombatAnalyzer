local CA = CombatAnalyzer
-- Interrupt statistics are recorded by the shared CombatLog.lua dispatcher.
function CA:GetInterruptCount(combat)
    return combat and combat.interrupts or 0
end
