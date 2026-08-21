local CA = CombatAnalyzer
-- Reads only the normalized `combat.abilities` table produced by
-- CombatLog.lua. No Retail/Classic branching needed or allowed here.
function CA:GetDamageRows(combat)
    local rows = {}
    if not combat then return rows end
    for _, a in pairs(combat.abilities) do
        table.insert(rows, a)
    end
    table.sort(rows, function(x,y) return x.damage > y.damage end)
    return rows
end
