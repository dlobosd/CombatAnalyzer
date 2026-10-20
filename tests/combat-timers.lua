-- Run from the repository root using Lua 5.1.
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
function GetBuildInfo() return 'test', 'test', 'test', 0 end
local now, fighting = 0, false
function GetTime() return now end
function UnitAffectingCombat() return fighting end
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
local callback, timers
local frame = {RegisterEvent = function() end}
function frame:SetScript(_, fn) callback = fn end
function CreateFrame() return frame end
timers = {}
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
dofile('Core.lua')
local CA = CombatAnalyzer
callback(nil, 'PLAYER_LOGIN')

-- A timer from a reset encounter must not close a subsequent encounter.
CA:StartCombat('old encounter')
callback(nil, 'PLAYER_REGEN_ENABLED')
CA:Reset()
now = 1
CA:StartCombat('new encounter')
local current = CA.current
callback(nil, 'PLAYER_REGEN_ENABLED')
now = 3
timers[1]()
assert(CA.inCombat and CA.current == current, 'stale timer must not end a new encounter')
now = 4
timers[2]()
assert(not CA.inCombat and #CA.history == 1, 'current encounter timer must still end combat')
assert(CA.history[1].duration == 3)

-- Reentering combat must continue to suppress the delayed end.
CA:StartCombat('still fighting')
callback(nil, 'PLAYER_REGEN_ENABLED')
fighting = true
timers[3]()
assert(CA.inCombat, 'active combat must not end')
print('PASS: stale encounter timers, normal delayed end and combat reentry')
