local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["XP Bar"],
  description = T["Replaces the default XP bar with a draggable bar showing rested XP as a purple overlay segment."],
  expansions = { ["vanilla"] = true, ["tbc"] = false },
  category = T["World & MiniMap"],
  enabled = true,
})

module.enable = function(self)

  -- ============================================================
  -- SAVED VARIABLES
  -- ============================================================

  if not ShaguTweaksXPbar then ShaguTweaksXPbar = {} end
  local defaults = {
    x = 0, y = 30,
    width = 400, height = 12,
    showText  = false,
    hoverText = true,
    gainText    = true,
    showTooltip = true,
    fontSize  = 10,
    xpColor         = { 0.2, 0.5, 0.9 },
    restedColor     = { 0.7, 0.2, 0.9 },
    textColor       = { 1.0, 1.0, 1.0 },
    restedTextColor = { 0.5, 0.8, 1.0 },
  }
  for k, v in pairs(defaults) do
    if ShaguTweaksXPbar[k] == nil then ShaguTweaksXPbar[k] = v end
  end
  local cfg = ShaguTweaksXPbar

  -- ============================================================
  -- KILL DEFAULT BLIZZ XP BAR
  -- ============================================================

  if MainMenuExpBar then
    MainMenuExpBar:Hide()
    MainMenuExpBar.Show = function() end
  end
  if ExhaustionTick then
    ExhaustionTick:Hide()
    ExhaustionTick.Show = function() end
  end
  if MainMenuBar_UpdateExperience then
    MainMenuBar_UpdateExperience = function() end
  end

  -- ============================================================
  -- BAR FRAME
  -- ============================================================

  local bar = CreateFrame("Frame", "ShaguTweaksXPbarFrame", UIParent)
  bar:SetWidth(cfg.width)
  bar:SetHeight(cfg.height)
  bar:SetPoint("BOTTOM", UIParent, "BOTTOM", cfg.x, cfg.y)
  bar:EnableMouse(true)
  bar:SetMovable(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetFrameStrata("HIGH")
  bar:SetClampedToScreen(true)

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar.bg:SetVertexColor(0.05, 0.05, 0.05, 0.8)

  bar.fill = bar:CreateTexture(nil, "ARTWORK")
  bar.fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

  bar.rested = bar:CreateTexture(nil, "ARTWORK")
  bar.rested:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar.rested:Hide()

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  bar.text:SetFont("Fonts\\FRIZQT__.TTF", cfg.fontSize, "OUTLINE")
  bar.text:Hide()

  -- apply saved colors
  bar.fill:SetVertexColor(cfg.xpColor[1], cfg.xpColor[2], cfg.xpColor[3], 1)
  bar.rested:SetVertexColor(cfg.restedColor[1], cfg.restedColor[2], cfg.restedColor[3], 1)
  bar.text:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3])

  -- ============================================================
  -- HELPERS
  -- ============================================================

  local textHovered = false
  local textGain    = false

  local function RefreshText()
    if cfg.showText or textHovered or textGain then
      bar.text:Show()
    else
      bar.text:Hide()
    end
  end

  local function ColorCode(c)
    return string.format("|cff%02x%02x%02x",
      math.floor(c[1] * 255 + 0.5),
      math.floor(c[2] * 255 + 0.5),
      math.floor(c[3] * 255 + 0.5))
  end

  -- ============================================================
  -- UPDATE BAR
  -- ============================================================

  local function UpdateBar()
    local maxXP = UnitXPMax("player")
    if maxXP == 0 then bar:Hide() return end
    bar:Show()

    local currXP  = UnitXP("player")
    local restXP  = GetXPExhaustion() or 0
    local w       = bar:GetWidth()
    local h       = bar:GetHeight()
    local fillPct = currXP / maxXP
    local fillW   = w * fillPct

    if fillW > 0 then
      bar.fill:ClearAllPoints()
      bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
      bar.fill:SetWidth(fillW)
      bar.fill:SetHeight(h)
      bar.fill:SetTexCoord(0, fillPct, 0, 1)
      bar.fill:Show()
    else
      bar.fill:Hide()
    end

    if restXP > 0 then
      local restedCapPct = math.min((currXP + restXP) / maxXP, 1)
      local restedW = w * (restedCapPct - fillPct)
      if restedW > 0 then
        bar.rested:ClearAllPoints()
        bar.rested:SetPoint("TOPLEFT", bar, "TOPLEFT", fillW, 0)
        bar.rested:SetWidth(restedW)
        bar.rested:SetHeight(h)
        bar.rested:SetTexCoord(0, restedCapPct - fillPct, 0, 1)
        bar.rested:Show()
      else
        bar.rested:Hide()
      end
    else
      bar.rested:Hide()
    end

    local pct  = math.floor(fillPct * 100)
    local text = currXP .. " / " .. maxXP .. " - " .. pct .. "%"
    if restXP > 0 then
      local restPct = math.floor((restXP / maxXP) * 100)
      text = text .. " - " .. ColorCode(cfg.restedTextColor) .. restPct .. "% rested|r"
    end
    bar.text:SetText(text)
    bar.text:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3])
    RefreshText()
  end

  -- ============================================================
  -- DRAG (ctrl + left drag)
  -- ============================================================

  bar:SetScript("OnDragStart", function()
    if IsControlKeyDown() then this:StartMoving() end
  end)

  bar:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local x = (this:GetLeft() + this:GetWidth() / 2) - (UIParent:GetLeft() + UIParent:GetWidth() / 2)
    local y = this:GetBottom() - UIParent:GetBottom()
    cfg.x = math.floor(x + 0.5)
    cfg.y = math.floor(y + 0.5)
  end)

  -- ============================================================
  -- RESIZE (ctrl + mousewheel)
  -- ============================================================

  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", function()
    if IsControlKeyDown() and IsShiftKeyDown() then
      cfg.height = math.max(2, math.min(60, cfg.height + arg1))
      bar:SetHeight(cfg.height)
      UpdateBar()
    elseif IsControlKeyDown() then
      cfg.width = math.max(100, math.min(700, cfg.width + arg1 * 10))
      bar:SetWidth(cfg.width)
      UpdateBar()
    end
  end)

  -- ============================================================
  -- TOOLTIP + HOVER TEXT
  -- ============================================================

  bar:SetScript("OnEnter", function()
    local maxXP = UnitXPMax("player")
    if maxXP == 0 then return end
    local currXP = UnitXP("player")
    local restXP = GetXPExhaustion() or 0
    local pct    = math.floor((currXP / maxXP) * 100)

    if cfg.showTooltip then
      GameTooltip:ClearLines()
      GameTooltip_SetDefaultAnchor(GameTooltip, this)
      GameTooltip:AddLine("Experience", 1, 0.82, 0)
      GameTooltip:AddDoubleLine("Progress:", currXP .. " / " .. maxXP .. " (" .. pct .. "%)", 1,1,1, 1,1,1)
      if restXP > 0 then
        local restPct = math.floor((restXP / maxXP) * 100)
        GameTooltip:AddDoubleLine("Rested:", restPct .. "% (" .. restXP .. " XP)", 0.5,0.8,1, 0.5,0.8,1)
      else
        GameTooltip:AddDoubleLine("Rested:", "None", 1,1,1, 0.6,0.6,0.6)
      end
      GameTooltip:Show()
    end

    if cfg.hoverText then
      textHovered = true
      RefreshText()
    end
  end)

  bar:SetScript("OnLeave", function()
    GameTooltip:Hide()
    textHovered = false
    RefreshText()
  end)

  -- ============================================================
  -- CONFIG PANEL (ctrl + right-click)
  -- ============================================================

  local configPanel  -- forward declaration so OnMouseDown can close it

  bar:SetScript("OnMouseDown", function()
    if arg1 == "RightButton" and IsControlKeyDown() then
      if configPanel:IsShown() then
        configPanel:Hide()
      else
        configPanel:ClearAllPoints()
        configPanel:SetPoint("BOTTOM", bar, "TOP", 0, 5)
        configPanel:Show()
      end
    end
  end)

  local cbIdx = 0
  local function MakeCheckbox(parent, label, yOff, getVal, setVal)
    cbIdx = cbIdx + 1
    local n  = "ShaguTweaksXPbarCB" .. cbIdx
    local cb = CreateFrame("CheckButton", n, parent, "OptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOff)
    cb:SetChecked(getVal())
    _G[n .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function()
      setVal(this:GetChecked() and true or false)
      RefreshText()
    end)
    return cb
  end

  local function MakeSwatch(parent, label, yOff, getColor, onConfirm)
    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetWidth(16)
    swatch:SetHeight(16)
    swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOff)
    swatch:EnableMouse(true)

    swatch.border = swatch:CreateTexture(nil, "BACKGROUND")
    swatch.border:SetAllPoints()
    swatch.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    swatch.border:SetVertexColor(0, 0, 0, 1)

    swatch.color = swatch:CreateTexture(nil, "ARTWORK")
    swatch.color:SetPoint("TOPLEFT",     swatch, "TOPLEFT",     1, -1)
    swatch.color:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1, 1)
    swatch.color:SetTexture("Interface\\Buttons\\WHITE8X8")
    local c = getColor()
    swatch.color:SetVertexColor(c[1], c[2], c[3], 1)

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
    lbl:SetText(label)

    swatch:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOPRIGHT")
      GameTooltip:SetText("Click to change")
      GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

    swatch:SetScript("OnClick", function()
      local col        = getColor()
      local pr, pg, pb = col[1], col[2], col[3]

      ColorPickerFrame.func = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        swatch.color:SetVertexColor(r, g, b, 1)
        onConfirm(r, g, b)
      end
      ColorPickerFrame.cancelFunc = function()
        swatch.color:SetVertexColor(pr, pg, pb, 1)
        onConfirm(pr, pg, pb)
      end
      ColorPickerFrame.hasOpacity = false
      ColorPickerFrame.opacityFunc = nil
      ColorPickerFrame:SetColorRGB(col[1], col[2], col[3])
      ShowUIPanel(ColorPickerFrame)
    end)

    return swatch
  end

  configPanel = CreateFrame("Frame", "ShaguTweaksXPbarConfig", UIParent)
  configPanel:SetWidth(220)
  configPanel:SetHeight(324)
  configPanel:SetFrameStrata("DIALOG")
  configPanel:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  configPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  configPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  configPanel:Hide()

  local panelTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panelTitle:SetPoint("TOP", configPanel, "TOP", 0, -10)
  panelTitle:SetText("XP Bar Options")

  MakeCheckbox(configPanel, "Always show text", -28,
    function() return cfg.showText  end,
    function(v) cfg.showText  = v   end)
  MakeCheckbox(configPanel, "Show text on hover", -52,
    function() return cfg.hoverText end,
    function(v) cfg.hoverText = v   end)
  MakeCheckbox(configPanel, "Show text on XP gain (5s)", -76,
    function() return cfg.gainText  end,
    function(v) cfg.gainText  = v   end)
  MakeCheckbox(configPanel, "Show tooltip on hover", -100,
    function() return cfg.showTooltip end,
    function(v) cfg.showTooltip = v   end)

  local divider = configPanel:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  10, -130)
  divider:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -10, -130)
  divider:SetHeight(1)
  divider:SetTexture("Interface\\Buttons\\WHITE8X8")
  divider:SetVertexColor(0.4, 0.4, 0.4, 0.8)

  local colorHeader = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  colorHeader:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 10, -138)
  colorHeader:SetText("Colors")

  MakeSwatch(configPanel, "XP Bar", -156,
    function() return cfg.xpColor end,
    function(r, g, b)
      cfg.xpColor = {r, g, b}
      bar.fill:SetVertexColor(r, g, b, 1)
    end)

  MakeSwatch(configPanel, "Rested Bar", -179,
    function() return cfg.restedColor end,
    function(r, g, b)
      cfg.restedColor = {r, g, b}
      bar.rested:SetVertexColor(r, g, b, 1)
    end)

  MakeSwatch(configPanel, "Text", -202,
    function() return cfg.textColor end,
    function(r, g, b)
      cfg.textColor = {r, g, b}
      bar.text:SetTextColor(r, g, b)
    end)

  MakeSwatch(configPanel, "Rested Text", -225,
    function() return cfg.restedTextColor end,
    function(r, g, b)
      cfg.restedTextColor = {r, g, b}
      UpdateBar()  -- rebuild text string with new inline color code
    end)

  local divider2 = configPanel:CreateTexture(nil, "ARTWORK")
  divider2:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  10, -246)
  divider2:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -10, -246)
  divider2:SetHeight(1)
  divider2:SetTexture("Interface\\Buttons\\WHITE8X8")
  divider2:SetVertexColor(0.4, 0.4, 0.4, 0.8)

  local fontSizeHeader = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fontSizeHeader:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 10, -254)
  fontSizeHeader:SetText("Font Size")

  local fontSizeVal = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fontSizeVal:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 110, -272)
  fontSizeVal:SetWidth(38)
  fontSizeVal:SetJustifyH("CENTER")
  fontSizeVal:SetText(tostring(cfg.fontSize))

  local fontSizeMinus = CreateFrame("Button", "ShaguTweaksXPbarFontMinus", configPanel, "GameMenuButtonTemplate")
  fontSizeMinus:SetWidth(30)
  fontSizeMinus:SetHeight(20)
  fontSizeMinus:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 80, -272)
  fontSizeMinus:SetText("-")
  fontSizeMinus:SetScript("OnClick", function()
    cfg.fontSize = math.max(6, cfg.fontSize - 1)
    bar.text:SetFont("Fonts\\FRIZQT__.TTF", cfg.fontSize, "OUTLINE")
    fontSizeVal:SetText(tostring(cfg.fontSize))
  end)

  local fontSizePlus = CreateFrame("Button", "ShaguTweaksXPbarFontPlus", configPanel, "GameMenuButtonTemplate")
  fontSizePlus:SetWidth(30)
  fontSizePlus:SetHeight(20)
  fontSizePlus:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 148, -272)
  fontSizePlus:SetText("+")
  fontSizePlus:SetScript("OnClick", function()
    cfg.fontSize = math.min(24, cfg.fontSize + 1)
    bar.text:SetFont("Fonts\\FRIZQT__.TTF", cfg.fontSize, "OUTLINE")
    fontSizeVal:SetText(tostring(cfg.fontSize))
  end)

  local closeBtn = CreateFrame("Button", nil, configPanel, "GameMenuButtonTemplate")
  closeBtn:SetWidth(80)
  closeBtn:SetHeight(20)
  closeBtn:SetPoint("BOTTOM", configPanel, "BOTTOM", 0, 8)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function() configPanel:Hide() end)

  -- ============================================================
  -- EVENTS
  -- ============================================================

  local gainTimer = 0

  local evFrame = CreateFrame("Frame")
  evFrame:RegisterEvent("PLAYER_XP_UPDATE")
  evFrame:RegisterEvent("PLAYER_LEVEL_UP")
  evFrame:RegisterEvent("UPDATE_EXHAUSTION")
  evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

  evFrame:SetScript("OnEvent", function()
    UpdateBar()
    if event == "PLAYER_XP_UPDATE" and cfg.gainText then
      textGain  = true
      gainTimer = 5
      RefreshText()
    end
  end)

  evFrame:SetScript("OnUpdate", function()
    if gainTimer > 0 then
      gainTimer = gainTimer - arg1
      if gainTimer <= 0 then
        gainTimer = 0
        textGain  = false
        RefreshText()
      end
    end
  end)

  UpdateBar()
end
