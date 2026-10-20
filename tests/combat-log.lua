-- Run from the repository root with a Lua 5.1 compatible interpreter.
for _, flavor in ipairs({'Retail', 'Classic'}) do
    CombatAnalyzer = {CombatLog = {}}
    local CL = CombatAnalyzer.CombatLog
    local received
    function CL:Dispatch(evt) received = evt end
    function CreateFrame()
        local frame = {RegisterEvent = function() end}
        function frame:SetScript(_, fn) self.OnEvent = fn end
        return frame
    end
    dofile('CombatLog_' .. flavor .. '.lua')
    CL['Init' .. flavor](CL)
    local frame = CL[flavor == 'Retail' and '_retailFrame' or '_classicFrame']
    local function send(kind, ...)
        local payload = {...}
        function CombatLogGetCurrentEventInfo()
            return 100, kind, false, 'player', 'Player', 1, 0,
                'enemy', 'Enemy', 2, 0, unpack(payload)
        end
        frame.OnEvent()
        assert(received.sourceGUID == 'player' and received.destGUID == 'enemy')
    end
    send('SWING_DAMAGE', 125, -1, 1, 0, 0, 0, true)
    assert(received.amount == 125, flavor .. ': swing damage must use the first payload field')
    assert(received.spellID == nil and received.spellName == nil, 'melee must not have a spell ID')
    assert(received.overkill == -1 and received.critical == true)
    send('SPELL_DAMAGE', 123, 'Fireball', 4, 250, -1, 4, 0, 0, 0, false)
    assert(received.spellID == 123 and received.spellName == 'Fireball')
    assert(received.amount == 250 and received.overkill == -1 and received.critical == false)
    send('RANGE_DAMAGE', 456, 'Shot', 1, 80, 0, 1, 0, 0, 0, true)
    assert(received.amount == 80 and received.critical == true)
    send('SPELL_HEAL', 789, 'Heal', 2, 150, 25, 0, true)
    assert(received.amount == 150, 'heal amount must remain intact')
    print('PASS: ' .. flavor .. ' raw melee, spell, ranged and healing payloads')
end
