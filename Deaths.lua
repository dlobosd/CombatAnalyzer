local CA = CombatAnalyzer
function CA:GetDeathCount(combat)
    return combat and combat.deaths or 0
end
