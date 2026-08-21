local CA = CombatAnalyzer

local frame = CreateFrame("Frame", "CombatAnalyzerFrame", UIParent, "BackdropTemplate")
frame:SetSize(720, 520)
frame:SetPoint("CENTER")
frame:SetBackdrop({
    bgFile = "Interface/Tooltips/Background",
    edgeFile = "Interface/Tooltips/Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left=4,right=4,top=4,bottom=4}
})
frame:Hide()
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOP", 0, -16)
title:SetText("Combat Analyzer")

local flavorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
flavorLabel:SetPoint("TOPRIGHT", -32, -20)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)

local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
summary:SetPoint("TOPLEFT", 20, -55)
summary:SetJustifyH("LEFT")

local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 20, -105)
scroll:SetPoint("BOTTOMRIGHT", -40, 20)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(620, 1)
scroll:SetScrollChild(content)

local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("TOPLEFT")
text:SetWidth(610)
text:SetJustifyH("LEFT")
text:SetSpacing(4)

local function FormatCombat(c)
    if not c then return "No completed combat yet." end
    local dps = c.duration > 0 and c.damage / c.duration or 0
    local hps = c.duration > 0 and c.healing / c.duration or 0
    local lines = {
        string.format("Duration: %.1fs", c.duration),
        string.format("Damage: %d   |   DPS: %.1f", c.damage, dps),
        string.format("Healing: %d   |   HPS: %.1f", c.healing, hps),
        string.format("Casts: %d   |   Interrupts: %d   |   Deaths: %d", c.casts, c.interrupts, c.deaths),
        "",
        "=== Damage by Ability ===",
    }
    for _, a in ipairs(CA:GetDamageRows(c)) do
        table.insert(lines, string.format("%s — %d damage — %d casts", a.name, a.damage, a.casts))
    end
    table.insert(lines, "")
    table.insert(lines, "=== Timeline ===")
    for _, e in ipairs(c.timeline) do
        local detail = e.spell or e.target or e.unit or ""
        local amount = e.amount and (" " .. e.amount) or ""
        table.insert(lines, string.format("[%6.2f] %-12s %s%s", e.t or 0, e.event or "", detail, amount))
    end
    return table.concat(lines, "\n")
end

function CA:RefreshUI()
    flavorLabel:SetText(self.ClientFlavor or "")
    local c = self.current or self.history[1]
    if c then
        summary:SetText("Latest combat analysis")
        text:SetText(FormatCombat(c))
        content:SetHeight(math.max(1, text:GetStringHeight()))
    else
        summary:SetText("No combat data")
        text:SetText("Enter combat and finish it, then return here.")
        content:SetHeight(1)
    end
end

function CA:ToggleUI()
    if frame:IsShown() then
        frame:Hide()
    else
        self:RefreshUI()
        frame:Show()
    end
end

-- Refresh while the window is visible.
frame:SetScript("OnShow", function() CA:RefreshUI() end)
