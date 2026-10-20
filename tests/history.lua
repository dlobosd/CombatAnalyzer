-- Run from the repository root with a Lua 5.1 compatible interpreter.
local frames = {}
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
function GetBuildInfo() return 'test', 'test', 'test', 0 end
local now = 0
function GetTime() return now end
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
function CreateFrame()
    local frame = {RegisterEvent = function() end}
    function frame:SetScript(event, fn) self[event] = fn end
    frames[#frames + 1] = frame
    return frame
end

dofile('Core.lua')
local CA = CombatAnalyzer
local login = frames[1].OnEvent
login(nil, 'PLAYER_LOGIN')
assert(CA.history == CombatAnalyzerDB.history, 'new history must use the saved table')
CA:StartCombat('test')
now = 5
CA:EndCombat('test')
assert(#CombatAnalyzerDB.history == 1, 'completed combat must be saved')

-- Reload the addon against the previously saved database.
dofile('Core.lua')
CA = CombatAnalyzer
frames[#frames].OnEvent(nil, 'PLAYER_LOGIN')
assert(#CA.history == 1, 'history must survive reload')
CA:Reset()
assert(#CombatAnalyzerDB.history == 0, 'reset must clear saved history')
assert(CA.history == CombatAnalyzerDB.history, 'reset must preserve the saved binding')
CA:StartCombat('after reset')
now = 10
CA:EndCombat('test')
assert(#CombatAnalyzerDB.history == 1, 'new combat after reset must be saved')

CombatAnalyzerDB = {}
frames[#frames].OnEvent(nil, 'PLAYER_LOGIN')
assert(CA.history == CombatAnalyzerDB.history, 'missing history must be initialized in DB')
print('PASS: history persists across reload and reset')
