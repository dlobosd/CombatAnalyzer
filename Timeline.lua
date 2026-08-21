local CA = CombatAnalyzer
function CA:GetTimeline(combat)
    return combat and combat.timeline or {}
end
