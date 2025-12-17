-- BugFarmMenu.lua (Обновленный)
--// SERVICES //--
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// CONFIGURATION //--
local ConfigFolder = "BBSR_Configs"
if makefolder then pcall(makefolder, ConfigFolder) end
local LayoutConfig = {
    TabSize = UDim2.new(0, 200, 0, 340),
    ContentSize = UDim2.new(0, 250, 0, 340),
    TabHiddenPos = UDim2.new(1, -250, 0.5, -170),
    TabVisiblePos = UDim2.new(1, -460, 0.5, -170),
    ContentVisiblePos = UDim2.new(1, -250, 0.5, -170),
    ContentHiddenPos = UDim2.new(1, 20, 0.5, -170),
    CollapsedPos = UDim2.new(1, 20, 0.5, -170),
    Font = Enum.Font.Code,
    TextSize = 13,
    ItemHeight = 24,
    SmallItemHeight = 20,
    AnimSpeed = 0.15
}
local Themes = {
    Blood = {Name="Blood", Main=Color3.fromRGB(12,0,0), Stroke=Color3.fromRGB(80,0,0), Accent=Color3.fromRGB(255,40,40), Dim=Color3.fromRGB(120,40,40), Text=Color3.fromRGB(230,230,230)},
    Hacker = {Name="Terminal", Main=Color3.fromRGB(10,10,10), Stroke=Color3.fromRGB(0,100,0), Accent=Color3.fromRGB(0,255,0), Dim=Color3.fromRGB(0,80,0), Text=Color3.fromRGB(200,255,200)},
    Midnight = {Name="Midnight", Main=Color3.fromRGB(15,15,25), Stroke=Color3.fromRGB(60,60,100), Accent=Color3.fromRGB(100,150,255), Dim=Color3.fromRGB(60,60,90), Text=Color3.fromRGB(240,240,255)},
    Ocean = {Name="Ocean", Main=Color3.fromRGB(5,15,25), Stroke=Color3.fromRGB(30,90,130), Accent=Color3.fromRGB(50,180,255), Dim=Color3.fromRGB(40,100,140), Text=Color3.fromRGB(220,240,255)},
    Purple = {Name="Purple", Main=Color3.fromRGB(20,10,30), Stroke=Color3.fromRGB(100,50,120), Accent=Color3.fromRGB(180,80,255), Dim=Color3.fromRGB(120,60,150), Text=Color3.fromRGB(240,220,255)}
}
local ColorPresets = {
    {Name="Red", R=255, G=0, B=0},
    {Name="Green", R=0, G=255, B=0},
    {Name="Blue", R=0, G=0, B=255},
    {Name="Yellow", R=255, G=255, B=0},
    {Name="Cyan", R=0, G=255, B=255},
    {Name="Magenta", R=255, G=0, B=255},
    {Name="White", R=255, G=255, B=255},
    {Name="Black", R=0, G=0, B=0}
}

--// STATE & UTILS //--
local State = {
    CurrentTheme = Themes.Blood,
    InTabs = true,
    IsCollapsed = false,
    IsInputting = false,
    TabIndex = 1,
    ItemIndex = 1,
    FileMode = false,
    ClipboardMode = false,
    TargetPicker = nil,
    JustOpenedParent = nil,
    IsAnimating = false,
    SearchMode = false,
    SearchQuery = "",
    AutoSave = false,
    LastConfig = "default",
    MenuVisible = true,
    UndoStack = {},
    RedoStack = {},
    -- Для DoubleTab
    InDoubleTab = false,
    InLeftTab = true
}
local Connections = {}
local ColorCache = {}
local NotificationQueue = {}

-- Performance: Color caching
local function GetCachedColor(r, g, b)
    local key = r.."_"..g.."_"..b
    if not ColorCache[key] then
        ColorCache[key] = Color3.fromRGB(r, g, b)
    end
    return ColorCache[key]
end
local function RGBtoHex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end
local function HexToRGB(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:gsub("[^%x]", "")
    if #hex < 6 then return nil end
    local r = tonumber("0x"..hex:sub(1,2))
    local g = tonumber("0x"..hex:sub(3,4))
    local b = tonumber("0x"..hex:sub(5,6))
    if r and g and b then return r, g, b end
    return nil
end

-- Функция для проверки, выбран ли элемент в комбобоксе
local function IsOptionSelected(comboBox, option)
    if not comboBox or not comboBox.Selected then return false end
    for _, selected in ipairs(comboBox.Selected) do
        if selected == option then
            return true
        end
    end
    return false
end

-- Функция для переключения выбора в комбобоксе
local function ToggleComboBoxOption(comboBox, option)
    if not comboBox then return end
    if not comboBox.Selected then
        comboBox.Selected = {}
    end
    local found = false
    for i, selected in ipairs(comboBox.Selected) do
        if selected == option then
            table.remove(comboBox.Selected, i)
            found = true
            break
        end
    end
    if not found then
        table.insert(comboBox.Selected, option)
    end
    -- Обновляем значение для отображения
    if #comboBox.Selected == 0 then
        comboBox.Value = "None"
    elseif #comboBox.Selected == 1 then
        comboBox.Value = comboBox.Selected[1]
    else
        comboBox.Value = tostring(#comboBox.Selected) .. " selected"
    end
end

-- Undo/Redo System
local function PushUndo(itemKey, oldValue)
    table.insert(State.UndoStack, {key = itemKey, value = oldValue})
    if #State.UndoStack > 20 then table.remove(State.UndoStack, 1) end
    State.RedoStack = {} -- Clear redo on new action
end

--// NOTIFICATION SYSTEM //--
local NotificationFrame = nil
local function CreateNotificationSystem()
    NotificationFrame = Instance.new("Frame")
    NotificationFrame.Name = "Notifications"
    NotificationFrame.Size = UDim2.new(0, 250, 0, 300)
    NotificationFrame.Position = UDim2.new(1, -260, 1, -310)
    NotificationFrame.BackgroundTransparency = 1
    NotificationFrame.Parent = ScreenGui
    local layout = Instance.new("UIListLayout", NotificationFrame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 5)
end

local function ShowNotification(text, duration)
    if not NotificationFrame then return end
    -- Use the setting from the core API
    local settings = _G.BugFarmAPI.GetConfig()
    if settings.ShowNotifications == false then return end
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 0)
    notif.BackgroundColor3 = State.CurrentTheme.Main
    notif.BorderSizePixel = 0
    notif.Parent = NotificationFrame
    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = State.CurrentTheme.Accent
    stroke.Thickness = 1
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = State.CurrentTheme.Text
    label.Font = LayoutConfig.Font
    label.TextSize = 12
    label.Text = tostring(text)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = notif
    -- Animate in
    TweenService:Create(notif, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 30)}):Play()
    -- Fade out and destroy
    task.delay(duration or 2, function()
        TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
        task.wait(0.3)
        notif:Destroy()
    end)
end

--// UI CREATION //--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BBSR_v9_0_BugFarm_Menu"
ScreenGui.ResetOnSpawn = false
if gethui then
    ScreenGui.Parent = gethui()
elseif game:GetService("CoreGui"):FindFirstChild("RobloxGui") then
    ScreenGui.Parent = game:GetService("CoreGui")
else
    ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function CreatePanel(name, pos, size)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = State.CurrentTheme.Main
    f.BorderSizePixel = 0
    f.Parent = ScreenGui
    local s = Instance.new("UIStroke")
    s.Color = State.CurrentTheme.Stroke
    s.Thickness = 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = f
    local h = Instance.new("TextLabel")
    h.Text = "bbsr // " .. (name or "")
    h.Size = UDim2.new(1, 0, 0, 15)
    h.Position = UDim2.new(0, 0, 0, -22)
    h.BackgroundTransparency = 1
    h.Font = LayoutConfig.Font
    h.TextColor3 = State.CurrentTheme.Accent
    h.TextSize = 12
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.Parent = f
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -10)
    scroll.Position = UDim2.new(0, 5, 0, 5)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = State.CurrentTheme.Accent
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.Parent = f
    local l = Instance.new("UIListLayout", scroll)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    return f, s, h, scroll
end

local TabFrame, TabStroke, TabHeader, TabScroll = CreatePanel("MAIN", LayoutConfig.TabHiddenPos, LayoutConfig.TabSize)
local ContentFrame, ContentStroke, ContentHeader, ContentScroll = CreatePanel("DATA", LayoutConfig.ContentHiddenPos, LayoutConfig.ContentSize)

-- Input Box (multi-purpose)
local InputFrame = Instance.new("Frame")
InputFrame.Size = UDim2.new(0, 220, 0, 40)
InputFrame.Position = UDim2.new(0.5, -110, 0.4, 0)
InputFrame.BackgroundColor3 = State.CurrentTheme.Main
InputFrame.Visible = false
InputFrame.Parent = ScreenGui
local InputStroke = Instance.new("UIStroke", InputFrame)
InputStroke.Color = State.CurrentTheme.Accent
InputStroke.Thickness = 2
local InputBox = Instance.new("TextBox")
InputBox.Size = UDim2.new(1, -10, 1, 0)
InputBox.Position = UDim2.new(0, 5, 0, 0)
InputBox.BackgroundTransparency = 1
InputBox.TextColor3 = State.CurrentTheme.Text
InputBox.Font = LayoutConfig.Font
InputBox.TextSize = 14
InputBox.PlaceholderText = "Enter Name..."
InputBox.Parent = InputFrame

-- Blacklist Edit Box (larger for multiple mobs)
local BlacklistFrame = Instance.new("Frame")
BlacklistFrame.Size = UDim2.new(0, 300, 0, 200)
BlacklistFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
BlacklistFrame.BackgroundColor3 = State.CurrentTheme.Main
BlacklistFrame.Visible = false
BlacklistFrame.Parent = ScreenGui
local BlacklistStroke = Instance.new("UIStroke", BlacklistFrame)
BlacklistStroke.Color = State.CurrentTheme.Accent
BlacklistStroke.Thickness = 2
local BlacklistLabel = Instance.new("TextLabel")
BlacklistLabel.Size = UDim2.new(1, 0, 0, 30)
BlacklistLabel.Position = UDim2.new(0, 0, 0, 0)
BlacklistLabel.BackgroundTransparency = 1
BlacklistLabel.TextColor3 = State.CurrentTheme.Accent
BlacklistLabel.Font = LayoutConfig.Font
BlacklistLabel.TextSize = 14
BlacklistLabel.Text = "Edit Blacklist (one per line)"
BlacklistLabel.TextXAlignment = Enum.TextXAlignment.Center
BlacklistLabel.Parent = BlacklistFrame
local BlacklistBox = Instance.new("TextBox")
BlacklistBox.Size = UDim2.new(1, -10, 1, -40)
BlacklistBox.Position = UDim2.new(0, 5, 0, 35)
BlacklistBox.BackgroundTransparency = 0.8
BlacklistBox.BackgroundColor3 = Color3.new(0, 0, 0)
BlacklistBox.TextColor3 = State.CurrentTheme.Text
BlacklistBox.Font = LayoutConfig.Font
BlacklistBox.TextSize = 12
BlacklistBox.TextWrapped = true
BlacklistBox.MultiLine = true
BlacklistBox.ClearTextOnFocus = false
BlacklistBox.Text = table.concat(_G.BugFarmAPI.Blacklist, "\n") -- Use API's blacklist
BlacklistBox.Parent = BlacklistFrame

-- Collapse Icon
local MiniIcon = Instance.new("Frame")
MiniIcon.Size = UDim2.new(0, 6, 0, 40)
MiniIcon.Position = UDim2.new(1, -10, 0.5, -20)
MiniIcon.BackgroundColor3 = State.CurrentTheme.Accent
MiniIcon.BackgroundTransparency = 1
MiniIcon.Visible = true
MiniIcon.Parent = ScreenGui

CreateNotificationSystem()

--// MENU DATA VALIDATION //--
local function ValidateItem(item, tabName)
    if not item or not item.Name or type(item.Name) ~= "string" then
        warn("[BBSR] Invalid item in tab '"..tostring(tabName).."': missing Name")
        return false
    end
    if item.Type == "Slider" then
        if type(item.Value) ~= "number" or type(item.Max) ~= "number" then
            warn("[BBSR] Slider '"..tostring(item.Name).."' needs numeric Value and Max")
            return false
        end
    elseif item.Type == "ColorPicker" then
        if type(item.R) ~= "number" or type(item.G) ~= "number" or type(item.B) ~= "number" then
            warn("[BBSR] ColorPicker '"..tostring(item.Name).."' needs R, G, B numbers")
            return false
        end
    elseif item.Type == "Dropdown" or item.Type == "ComboBox" then
        if not item.Options or type(item.Options) ~= "table" then
            warn("[BBSR] "..tostring(item.Type).." '"..tostring(item.Name).."' needs Options table")
            return false
        end
    end
    return true
end

--// MENU DATA //--
local MenuData = {
    {
        Name = "Bug Farm",
        Items = {
            {Type = "Button", Name = "Enabled", State = false, Callback = function(state)
                if state then
                    _G.BugFarmAPI.ForceStart() -- Use API to start/enable
                    ShowNotification("Bug Farm: ON", 1.5)
                else
                    _G.BugFarmAPI.Stop() -- Use API to stop/disable
                    ShowNotification("Bug Farm: OFF", 1.5)
                end
            end},
            -- NEW: Pause Button
            {Type = "Button", Name = "Paused", State = false, Callback = function(state)
                 if state then
                     _G.BugFarmAPI.Pause() -- Use API to pause
                     ShowNotification("Bug Farm: Paused", 1.5)
                 else
                     _G.BugFarmAPI.Resume() -- Use API to resume
                     ShowNotification("Bug Farm: Resumed", 1.5)
                 end
             end},
             -- NEW: Pine Tree Distance Slider
             {Type = "Slider", Name = "Pine Tree Distance", Value = 20, Max = 50, Min = 5, Callback = function(value)
                 _G.BugFarmAPI.SetConfig({PineTreeApproachDistance = value}) -- Use API to update
             end},
            {Type = "Slider", Name = "Scan Radius", Value = 80, Max = 200, Callback = function(value)
                _G.BugFarmAPI.SetConfig({MobScanRadius = value}) -- Use API to update
            end},
            {Type = "Slider", Name = "Check Interval", Value = 5, Max = 30, Callback = function(value)
                _G.BugFarmAPI.SetConfig({CheckInterval = value}) -- Use API to update
            end},
            {Type = "Slider", Name = "Loot Speed", Value = 80, Max = 200, Callback = function(value)
                _G.BugFarmAPI.SetConfig({WalkSpeedDuringLoot = value}) -- Use API to update
            end},
            {Type = "Slider", Name = "Cooldown Multiplier", Value = 1.0, Max = 3.0, Precision = 0.1, Callback = function(value)
                _G.BugFarmAPI.SetConfig({CooldownMultiplier = value}) -- Use API to update
            end},
            {Type = "Button", Name = "Auto Convert Pollen", State = true, Callback = function(state)
                _G.BugFarmAPI.SetConfig({AutoConvertPollen = state}) -- Use API to update
            end},
            {Type = "Button", Name = "Auto Loot", State = true, Callback = function(state)
                _G.BugFarmAPI.SetConfig({AutoLoot = state}) -- Use API to update
            end},
            {Type = "Button", Name = "Jump Dodge", State = true, Callback = function(state)
                _G.BugFarmAPI.SetConfig({JumpDodgeEnabled = state}) -- Use API to update
            end},
            {Type = "Button", Name = "Notifications", State = true, Callback = function(state)
                _G.BugFarmAPI.SetConfig({ShowNotifications = state}) -- Use API to update
            end},
            {Type = "Action", Name = "Edit Blacklist", Action = "EditBlacklist"},
            {Type = "Action", Name = "Force Start", Action = "ForceStartBugFarm"},
            {Type = "Action", Name = "Stop Farm", Action = "StopBugFarm"}
        }
    },
    {
        Name = "Settings",
        Items = {
            {Type = "Dropdown", Name = "Theme", Options = {"Blood", "Terminal", "Midnight", "Ocean", "Purple"}, Value = "Blood", Callback = function(v)
                for _, t in pairs(Themes) do
                    if t.Name == v then
                        State.CurrentTheme = t
                        ShowNotification("Theme: "..tostring(v), 1.5)
                    end
                end
            end},
            {Type = "Button", Name = "Auto-Save", State = false, Callback = function(s)
                State.AutoSave = s
                ShowNotification("Auto-save: "..(s and "ON" or "OFF"), 1.5)
            end},
            {Type = "Action", Name = "Save Config", Action = "Save"},
            {Type = "Action", Name = "Load Config", Action = "Load"},
            {Type = "Action", Name = "Search Items", Action = "Search"},
            {Type = "Button", Name = "Unload Menu", Callback = function()
                _G.BugFarmAPI.Stop() -- Use API to stop
                ShowNotification("Unloading...", 1)
                task.wait(0.5)
                UnloadMenu()
            end}
        }
    }
}

-- Validate all items on startup
for _, tab in ipairs(MenuData) do
    if tab.Type == "DoubleTab" then
        for _, side in ipairs({tab.Left, tab.Right}) do
            if side and side.Items then
                for i = #side.Items, 1, -1 do
                    if not ValidateItem(side.Items[i], tab.Name) then
                        table.remove(side.Items, i)
                    end
                end
            end
        end
    elseif tab.Items then
        for i = #tab.Items, 1, -1 do
            if not ValidateItem(tab.Items[i], tab.Name) then
                table.remove(tab.Items, i)
            end
        end
    end
end

--// UNLOAD LOGIC //--
local function UnloadMenu()
    ContextActionService:UnbindAction("MenuSink")
    ContextActionService:UnbindAction("MenuToggle")
    ContextActionService:UnbindAction("BugFarmF1") -- Unbind F1
    ContextActionService:UnbindAction("BugFarmF2") -- Unbind F2
    ContextActionService:UnbindAction("BugFarmF3") -- Unbind F3
    for _, connection in pairs(Connections) do
        if connection then connection:Disconnect() end
    end
    Connections = {}
    if ScreenGui then ScreenGui:Destroy() end
    ColorCache = {}
end

--// SAVE & LOAD SYSTEM //--
local function SaveConfig(name)
    if not name or name == "" then name = "default" end
    local data = {
        Theme = State.CurrentTheme.Name,
        AutoSave = State.AutoSave,
        BugFarm = _G.BugFarmAPI.GetConfig(), -- Save from API
        Elements = {}
    }
    for _, tab in ipairs(MenuData) do
        if not tab then continue end
        if tab.Type == "DoubleTab" then
            if not tab.Name then continue end
            for _, side in ipairs({tab.Left, tab.Right}) do
                if not side or not side.Name or not side.Items then continue end
                for _, item in ipairs(side.Items) do
                    if item and item.Name then
                        local key = tostring(tab.Name) .. "_" .. tostring(side.Name) .. "_" .. tostring(item.Name)
                        local val = nil
                        if item.Type == "Button" then val = item.State
                        elseif item.Type == "Slider" then val = item.Value
                        elseif item.Type == "Dropdown" then val = item.Value
                        elseif item.Type == "ComboBox" then val = item.Selected or {}
                        elseif item.Type == "ColorPicker" then val = {R=item.R or 255, G=item.G or 255, B=item.B or 255}
                        end
                        if val ~= nil then data.Elements[key] = val end
                    end
                end
            end
        elseif tab.Items then
            if not tab.Name then continue end
            for _, item in ipairs(tab.Items) do
                if item and item.Name then
                    local key = tostring(tab.Name) .. "_" .. tostring(item.Name)
                    local val = nil
                    if item.Type == "Button" then val = item.State
                    elseif item.Type == "Slider" then val = item.Value
                    elseif item.Type == "Dropdown" then val = item.Value
                    elseif item.Type == "ComboBox" then val = item.Selected or {}
                    elseif item.Type == "ColorPicker" then val = {R=item.R or 255, G=item.G or 255, B=item.B or 255}
                    end
                    if val ~= nil then data.Elements[key] = val end
                end
            end
        end
    end
    if writefile then
        local success, err = pcall(function()
            writefile(ConfigFolder.."/"..tostring(name)..".json", HttpService:JSONEncode(data))
        end)
        if success then
            State.LastConfig = name
            ShowNotification("Saved: "..tostring(name), 2)
        else
            ShowNotification("Save failed!", 2)
            warn("[BBSR] Save error:", err)
        end
    end
end

local function LoadConfig(name)
    if not readfile or not isfile(ConfigFolder.."/"..tostring(name)) then
        ShowNotification("Config not found", 2)
        return
    end
    local content = readfile(ConfigFolder.."/"..tostring(name))
    local decoded, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not decoded or not data then
        ShowNotification("Invalid config file", 2)
        return
    end
    if data.Theme then
        for _, t in pairs(Themes) do
            if t.Name == data.Theme then
                State.CurrentTheme = t
                break
            end
        end
    end
    if data.AutoSave ~= nil then State.AutoSave = data.AutoSave end
    -- Load Bug Farm settings using API
    if data.BugFarm then
        _G.BugFarmAPI.SetConfig(data.BugFarm) -- Use API to load settings
        -- Update the blacklist box text if core was loaded
        if BlacklistBox then
            BlacklistBox.Text = table.concat(_G.BugFarmAPI.Blacklist, "\n")
        end
        -- Update Pause button state based on loaded config
        local pauseItem = nil
        for _, item in ipairs(MenuData[1].Items) do
            if item.Name == "Paused" and item.Type == "Button" then
                pauseItem = item
                break
            end
        end
        if pauseItem then
            pauseItem.State = data.BugFarm.Paused or false
        end
        -- Update Pine Tree Distance slider state based on loaded config
        local distanceItem = nil
        for _, item in ipairs(MenuData[1].Items) do
            if item.Name == "Pine Tree Distance" and item.Type == "Slider" then
                distanceItem = item
                break
            end
        end
        if distanceItem then
            distanceItem.Value = data.BugFarm.PineTreeApproachDistance or 20
        end
    end
    if data.Elements then
        for _, tab in ipairs(MenuData) do
            if not tab then continue end
            if tab.Type == "DoubleTab" then
                if not tab.Name then continue end
                for _, side in ipairs({tab.Left, tab.Right}) do
                    if not side or not side.Name or not side.Items then continue end
                    for _, item in ipairs(side.Items) do
                        if not item or not item.Name then continue end
                        local key = tostring(tab.Name) .. "_" .. tostring(side.Name) .. "_" .. tostring(item.Name)
                        local saved = data.Elements[key]
                        if saved ~= nil then
                            if item.Type == "Button" then
                                item.State = saved
                                if item.Callback then
                                    pcall(item.Callback, item.State)
                                end
                            elseif item.Type == "Slider" then
                                item.Value = saved
                            elseif item.Type == "Dropdown" then
                                item.Value = saved
                            elseif item.Type == "ComboBox" then
                                item.Selected = saved or {}
                                -- Обновляем значение для отображения
                                if not item.Selected or #item.Selected == 0 then
                                    item.Value = "None"
                                elseif #item.Selected == 1 then
                                    item.Value = item.Selected[1]
                                else
                                    item.Value = tostring(#item.Selected) .. " selected"
                                end
                            elseif item.Type == "ColorPicker" and type(saved) == "table" then
                                item.R = saved.R or 255
                                item.G = saved.G or 255
                                item.B = saved.B or 255
                            end
                        end
                    end
                end
            elseif tab.Items then
                if not tab.Name then continue end
                for _, item in ipairs(tab.Items) do
                    if not item or not item.Name then continue end
                    local key = tostring(tab.Name) .. "_" .. tostring(item.Name)
                    local saved = data.Elements[key] or data.Elements[tostring(item.Name)]
                    if saved ~= nil then
                        if item.Type == "Button" then
                            item.State = saved
                            if item.Callback then
                                pcall(item.Callback, item.State)
                            end
                        elseif item.Type == "Slider" then
                            item.Value = saved
                        elseif item.Type == "Dropdown" then
                            item.Value = saved
                        elseif item.Type == "ComboBox" then
                            item.Selected = saved or {}
                            -- Обновляем значение для отображения
                            if not item.Selected or #item.Selected == 0 then
                                item.Value = "None"
                            elseif #item.Selected == 1 then
                                item.Value = item.Selected[1]
                            else
                                item.Value = tostring(#item.Selected) .. " selected"
                            end
                        elseif item.Type == "ColorPicker" and type(saved) == "table" then
                            item.R = saved.R or 255
                            item.G = saved.G or 255
                            item.B = saved.B or 255
                        end
                    end
                end
            end
        end
    end
    State.LastConfig = name:gsub(".json", "")
    ShowNotification("Loaded: "..name:gsub(".json", ""), 2)
    UpdateVisuals()
end

--// RENDERING LOGIC //--
local Labels = {Tabs = {}, Content = {}}
local CurrentItems = {}

local function ApplyTheme()
    local T = State.CurrentTheme
    if TabFrame then TabFrame.BackgroundColor3 = T.Main end
    if ContentFrame then ContentFrame.BackgroundColor3 = T.Main end
    if InputFrame then InputFrame.BackgroundColor3 = T.Main end
    if BlacklistFrame then BlacklistFrame.BackgroundColor3 = T.Main end
    if TabStroke then TabStroke.Color = T.Stroke end
    if ContentStroke then ContentStroke.Color = T.Stroke end
    if InputStroke then InputStroke.Color = T.Accent end
    if BlacklistStroke then BlacklistStroke.Color = T.Accent end
    if TabHeader then TabHeader.TextColor3 = T.Accent end
    if ContentHeader then ContentHeader.TextColor3 = T.Accent end
    if TabScroll then TabScroll.ScrollBarImageColor3 = T.Accent end
    if ContentScroll then ContentScroll.ScrollBarImageColor3 = T.Accent end
    if InputBox then InputBox.TextColor3 = T.Text end
    if BlacklistBox then
        BlacklistBox.TextColor3 = T.Text
        BlacklistBox.BackgroundColor3 = Color3.new(0, 0, 0)
    end
    if BlacklistLabel then BlacklistLabel.TextColor3 = T.Accent end
    if MiniIcon then MiniIcon.BackgroundColor3 = T.Accent end
end

local function UpdateScrolling(scroller, index, total)
    if not scroller then return end
    local dispH = scroller.AbsoluteSize.Y
    local targetY = 0
    local totalH = 0
    for i = 1, #CurrentItems do
        local h = CurrentItems[i] and (CurrentItems[i].Height or LayoutConfig.ItemHeight) or LayoutConfig.ItemHeight
        if i < index then targetY = targetY + h end
        totalH = totalH + h
    end
    if scroller == TabScroll then
        totalH = total * LayoutConfig.ItemHeight
        targetY = (index - 1) * LayoutConfig.ItemHeight
    end
    scroller.CanvasSize = UDim2.new(0, 0, 0, totalH)
    local currentItemH = (CurrentItems[index] and (CurrentItems[index].Height or LayoutConfig.ItemHeight)) or LayoutConfig.ItemHeight
    if targetY + currentItemH > scroller.CanvasPosition.Y + dispH then
        scroller.CanvasPosition = Vector2.new(0, targetY + currentItemH - dispH)
    elseif targetY < scroller.CanvasPosition.Y then
        scroller.CanvasPosition = Vector2.new(0, targetY)
    end
end

local function CreateLabel(parent, item, realItem)
    local h = item and item.Height or LayoutConfig.ItemHeight
    local container = Instance.new("Frame")
    container.Name = "ItemContainer"
    container.Size = UDim2.new(1, 0, 0, h)
    container.BackgroundTransparency = 1
    container.Parent = parent
    if item and item.Type == "ColorPicker" then
        container.ZIndex = 10
        container.ClipsDescendants = false
    else
        container.ZIndex = 1
        container.ClipsDescendants = true
    end
    local isSubItem = item and (item.IsOption or item.Type == "ColorOption" or item.Type == "ColorAction" or item.Type == "ColorPreset")
    if isSubItem and item.Parent == State.JustOpenedParent then
        container.Size = UDim2.new(1, 0, 0, 0)
        TweenService:Create(container, TweenInfo.new(LayoutConfig.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, h)}):Play()
    end
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -5, 1, 0)
    l.BackgroundTransparency = 1
    l.Font = LayoutConfig.Font
    l.TextSize = LayoutConfig.TextSize
    l.TextColor3 = State.CurrentTheme.Text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = container.ZIndex + 1
    l.Parent = container
    local colorBox = Instance.new("Frame")
    colorBox.Name = "ColorBox"
    colorBox.Size = UDim2.new(0, 12, 0, 12)
    colorBox.Position = UDim2.new(1, -20, 0.5, -6)
    colorBox.BorderSizePixel = 0
    colorBox.Visible = false
    colorBox.ZIndex = container.ZIndex + 2
    colorBox.Parent = container
    if realItem and realItem.Type == "ColorPicker" then
        colorBox.Visible = true
        if realItem.Expanded then
            colorBox.Size = UDim2.new(0, 60, 0, 60)
            colorBox.Position = UDim2.new(0, 5, 1, 5)
        else
            colorBox.Size = UDim2.new(0, 12, 0, 12)
            colorBox.Position = UDim2.new(1, -20, 0.5, -6)
        end
    end
    local btnBorder = Instance.new("Frame")
    btnBorder.Name = "BtnBorder"
    btnBorder.Size = UDim2.new(0, 0, 0, 0)
    btnBorder.BackgroundTransparency = 1
    btnBorder.Visible = false
    btnBorder.ZIndex = container.ZIndex + 1
    btnBorder.Parent = container
    local btnStroke = Instance.new("UIStroke", btnBorder)
    btnStroke.Thickness = 1
    btnStroke.Color = State.CurrentTheme.Accent
    return {Frame = container, Label = l, ColorBox = colorBox, BtnBorder = btnBorder, BtnStroke = btnStroke, Item = item}
end

local function UpdateVisuals()
    if not ScreenGui or not ScreenGui.Parent then return end
    ApplyTheme()
    local T = State.CurrentTheme
    -- Update tab list
    for i, obj in ipairs(Labels.Tabs) do
        local tab = MenuData[i]
        if not tab then break end
        if i == State.TabIndex then
            obj.Label.TextColor3 = T.Accent
            if tab.Type == "DoubleTab" then
                -- Простая индикация DoubleTab
                obj.Label.Text = (State.InTabs and "> " or "* ") .. (tab.Name or "") .. " [2]"
            else
                obj.Label.Text = (State.InTabs and "> " or "* ") .. (tab.Name or "")
            end
        else
            obj.Label.TextColor3 = T.Dim
            if tab.Type == "DoubleTab" then
                obj.Label.Text = "  " .. (tab.Name or "") .. " [2]"
            else
                obj.Label.Text = "  " .. (tab.Name or "")
            end
        end
        obj.ColorBox.Visible = false
    end
    -- Обновляем контент
    for i, obj in ipairs(Labels.Content) do
        local item = CurrentItems[i]
        if not item then break end
        local isSel = (not State.InTabs and i == State.ItemIndex)
        local text = ""
        obj.ColorBox.Visible = false
        obj.BtnBorder.Visible = false
        obj.Label.TextXAlignment = Enum.TextXAlignment.Left
        obj.Label.Position = UDim2.new(0, 0, 0, 0)
        obj.Label.Size = UDim2.new(1, -5, 1, 0)
        if item.Type == "Back" then
            text = "[ .. ] BACK"
        elseif item.Type == "TabSwitch" then
            text = item.Name or ""
            obj.Label.TextXAlignment = Enum.TextXAlignment.Center
            obj.Label.TextColor3 = T.Accent
            obj.Label.Font = Enum.Font.Code
            obj.Label.TextSize = LayoutConfig.TextSize
            obj.Label.Text = text
            continue
        elseif item.Type == "TabHeader" then
            text = item.Name or ""
            obj.Label.TextXAlignment = Enum.TextXAlignment.Left
            obj.Label.TextColor3 = T.Accent
            obj.Label.Font = Enum.Font.Code
            obj.Label.TextSize = LayoutConfig.TextSize
            obj.Label.Text = text
            continue
        elseif item.Type == "Refresh" then
            text = "[ UPDATE LIST ]"
        elseif item.Type == "File" then
            text = "FILE: " .. (item.Name or "")
        elseif item.Type == "Button" then
            -- Special handling for "Paused" button to reflect actual API state
            if item.Name == "Paused" and item.Type == "Button" then
                local apiState = _G.BugFarmAPI.GetConfig().Paused
                item.State = apiState -- Sync item state with API
                text = (apiState and "[x] " or "[ ] ") .. (item.Name or "")
            else
                text = (item.State and "[x] " or "[ ] ") .. (item.Name or "")
            end
        elseif item.Type == "Action" then
            text = "[RUN] " .. (item.Name or "")
        elseif item.Type == "ColorPicker" then
            text = item.Name or ""
            obj.ColorBox.Visible = true
            obj.ColorBox.BackgroundColor3 = GetCachedColor(item.R or 255, item.G or 255, item.B or 255)
        elseif item.Type == "ColorOption" then
            local w = 6
            local fill = math.floor(((item.Value or 0) / (item.Max or 255)) * w)
            text = (item.Name or "") .. " [" .. string.rep("|", fill) .. string.rep(".", w - fill) .. "] " .. (item.Value or 0)
            obj.Label.Position = UDim2.new(0, 70, 0, 0)
            obj.Label.Size = UDim2.new(1, -75, 1, 0)
        elseif item.Type == "ColorAction" then
            text = item.Name or ""
            obj.Label.TextXAlignment = Enum.TextXAlignment.Center
            obj.BtnBorder.Visible = true
            obj.BtnBorder.Size = UDim2.new(0, 80, 0, 16)
            obj.BtnBorder.Position = UDim2.new(0, 70, 0.5, -8)
            obj.BtnStroke.Color = isSel and T.Accent or T.Dim
            obj.Label.Parent = obj.BtnBorder
            obj.Label.Size = UDim2.new(1,0,1,0)
            obj.Label.Position = UDim2.new(0,0,0,0)
        elseif item.Type == "ColorPreset" then
            text = item.Name or ""
            obj.ColorBox.Visible = true
            obj.ColorBox.BackgroundColor3 = GetCachedColor(item.R or 255, item.G or 255, item.B or 255)
            obj.ColorBox.Size = UDim2.new(0, 14, 0, 14)
            obj.ColorBox.Position = UDim2.new(0, 10, 0.5, -7)
            obj.Label.Position = UDim2.new(0, 30, 0, 0)
        elseif item.Type == "Slider" then
            local w = 8
            local fill = math.floor(((item.Value or 0) / (item.Max or 100)) * w)
            text = (item.Name or "") .. " [" .. string.rep("|", fill) .. string.rep(".", w - fill) .. "] " .. math.floor(item.Value or 0)
        elseif item.Type == "Dropdown" then
            local arrow = item.Expanded and "v" or ">"
            text = (item.Name or "") .. " [" .. (item.Value or "") .. "] " .. arrow
            if item.IsOption then
                text = "  - " .. (item.Name or "")
                if isSel then text = "  > " .. (item.Name or "") end
            end
        elseif item.Type == "ComboBox" then
            local arrow = item.Expanded and "v" or ">"
            text = (item.Name or "") .. " [" .. (item.Value or "") .. "] " .. arrow
            if item.IsOption then
                -- Показываем галочку для выбранных элементов
                local check = IsOptionSelected(item.Parent, item.Name) and "[x] " or "[ ] "
                text = check .. (item.Name or "")
                if isSel then text = "> " .. check .. (item.Name or "") end
            end
        end
        if item.Type ~= "ColorAction" and item.Type ~= "TabSwitch" and item.Type ~= "TabHeader" then
            if isSel and not item.IsOption and item.Type ~= "ColorPreset" then
                obj.Label.Text = "> " .. text
                obj.Label.TextColor3 = T.Accent
            else
                obj.Label.Text = (item.IsOption and "" or "  ") .. text
                obj.Label.TextColor3 = T.Text
            end
        elseif item.Type == "ColorAction" then
            obj.Label.Text = text
            obj.Label.TextColor3 = isSel and T.Accent or T.Text
        end
        if (item.IsOption or item.Type == "ColorPreset") and isSel then
            obj.Label.TextColor3 = T.Accent
        end
    end
    if State.InTabs then
        UpdateScrolling(TabScroll, State.TabIndex, #MenuData)
    else
        UpdateScrolling(ContentScroll, State.ItemIndex, #CurrentItems)
    end
end

local function RefreshList()
    if not ScreenGui or not ScreenGui.Parent then return end
    -- Очищаем предыдущие элементы
    for _, l in ipairs(Labels.Content) do
        if l and l.Frame then l.Frame:Destroy() end
    end
    Labels.Content = {}
    CurrentItems = {}
    local currentTab = MenuData[State.TabIndex]
    if not currentTab then return end
    -- Проверяем, является ли текущая вкладка DoubleTab
    if currentTab.Type == "DoubleTab" then
        State.InDoubleTab = true
        -- Простая индикация текущего таба
        if State.InLeftTab then
            table.insert(CurrentItems, {
                Type = "TabSwitch",
                Name = "← Press ← → to switch tabs →",
                TargetTab = "right",
                Hint = true
            })
            table.insert(CurrentItems, {
                Type = "TabHeader",
                Name = "» CHARACTER «",
                IsHeader = true
            })
        else
            table.insert(CurrentItems, {
                Type = "TabSwitch",
                Name = "← Press ← → to switch tabs →",
                TargetTab = "left",
                Hint = true
            })
            table.insert(CurrentItems, {
                Type = "TabHeader",
                Name = "» TOOLS «",
                IsHeader = true
            })
        end
        -- Добавляем элементы из выбранного подтаба
        local selectedTab = State.InLeftTab and currentTab.Left or currentTab.Right
        for _, item in ipairs(selectedTab.Items) do
            table.insert(CurrentItems, item)
            if item.Type == "Dropdown" and item.Expanded then
                for _, opt in ipairs(item.Options) do
                    table.insert(CurrentItems, {
                        Type="Dropdown",
                        Name=opt,
                        IsOption=true,
                        Parent=item,
                        Value=""
                    })
                end
            end
            if item.Type == "ComboBox" and item.Expanded then
                for _, opt in ipairs(item.Options) do
                    table.insert(CurrentItems, {
                        Type="ComboBox",
                        Name=opt,
                        IsOption=true,
                        Parent=item,
                        Value=""
                    })
                end
            end
            if item.Type == "ColorPicker" and item.Expanded then
                local h = LayoutConfig.SmallItemHeight
                table.insert(CurrentItems, {Type="ColorOption", Name="R", Value=item.R or 0, Max=255, Parent=item, Height=h})
                table.insert(CurrentItems, {Type="ColorOption", Name="G", Value=item.G or 0, Max=255, Parent=item, Height=h})
                table.insert(CurrentItems, {Type="ColorOption", Name="B", Value=item.B or 0, Max=255, Parent=item, Height=h})
                table.insert(CurrentItems, {Type="ColorAction", Name="COPY", Action="Copy", Parent=item, Height=h})
                table.insert(CurrentItems, {Type="ColorAction", Name="PASTE", Action="Paste", Parent=item, Height=h})
                for _, preset in ipairs(ColorPresets) do
                    table.insert(CurrentItems, {
                        Type="ColorPreset",
                        Name=preset.Name,
                        R=preset.R,
                        G=preset.G,
                        B=preset.B,
                        Parent=item,
                        Height=h
                    })
                end
            end
        end
    else
        State.InDoubleTab = false
        State.InLeftTab = true
        -- Старая логика для обычных вкладок
        if State.FileMode then
            table.insert(CurrentItems, {Type = "Back", Name = "CANCEL"})
            table.insert(CurrentItems, {Type = "Refresh", Name = "REFRESH"})
            if listfiles then
                for _, f in ipairs(listfiles(ConfigFolder)) do
                    if f:sub(-5) == ".json" then
                        table.insert(CurrentItems, {Type="File", Name=f:match("([^/]+)$") or "", Path=f})
                    end
                end
            end
        elseif State.SearchMode then
            table.insert(CurrentItems, {Type = "Back", Name = "EXIT SEARCH"})
            local query = State.SearchQuery:lower()
            for tabIdx, tab in ipairs(MenuData) do
                if tab.Type == "DoubleTab" then
                    for _, side in ipairs({tab.Left, tab.Right}) do
                        if side and side.Items then
                            for _, item in ipairs(side.Items) do
                                if item.Name and item.Name:lower():find(query, 1, true) then
                                    local copy = {}
                                    for k, v in pairs(item) do copy[k] = v end
                                    copy.TabOrigin = (tab.Name or "") .. " (" .. (side.Name or "") .. ")"
                                    table.insert(CurrentItems, copy)
                                end
                            end
                        end
                    end
                elseif tab.Items then
                    for _, item in ipairs(tab.Items) do
                        if item.Name and item.Name:lower():find(query, 1, true) then
                            local copy = {}
                            for k, v in pairs(item) do copy[k] = v end
                            copy.TabOrigin = tab.Name or ""
                            table.insert(CurrentItems, copy)
                        end
                    end
                end
            end
            if #CurrentItems == 1 then
                table.insert(CurrentItems, {Type = "Action", Name = "No results found"})
            end
        elseif currentTab.Items then
            table.insert(CurrentItems, {Type = "Back", Name = "BACK"})
            local items = currentTab.Items
            for _, item in ipairs(items) do
                table.insert(CurrentItems, item)
                if item.Type == "Dropdown" and item.Expanded then
                    for _, opt in ipairs(item.Options) do
                        table.insert(CurrentItems, {
                            Type="Dropdown",
                            Name=opt,
                            IsOption=true,
                            Parent=item,
                            Value=""
                        })
                    end
                end
                if item.Type == "ComboBox" and item.Expanded then
                    for _, opt in ipairs(item.Options) do
                        table.insert(CurrentItems, {
                            Type="ComboBox",
                            Name=opt,
                            IsOption=true,
                            Parent=item,
                            Value=""
                        })
                    end
                end
                if item.Type == "ColorPicker" and item.Expanded then
                    local h = LayoutConfig.SmallItemHeight
                    table.insert(CurrentItems, {Type="ColorOption", Name="R", Value=item.R or 0, Max=255, Parent=item, Height=h})
                    table.insert(CurrentItems, {Type="ColorOption", Name="G", Value=item.G or 0, Max=255, Parent=item, Height=h})
                    table.insert(CurrentItems, {Type="ColorOption", Name="B", Value=item.B or 0, Max=255, Parent=item, Height=h})
                    table.insert(CurrentItems, {Type="ColorAction", Name="COPY", Action="Copy", Parent=item, Height=h})
                    table.insert(CurrentItems, {Type="ColorAction", Name="PASTE", Action="Paste", Parent=item, Height=h})
                    for _, preset in ipairs(ColorPresets) do
                        table.insert(CurrentItems, {
                            Type="ColorPreset",
                            Name=preset.Name,
                            R=preset.R,
                            G=preset.G,
                            B=preset.B,
                            Parent=item,
                            Height=h
                        })
                    end
                end
            end
        end
    end
    for i, item in ipairs(CurrentItems) do
        local realSource = item
        if item.Parent then realSource = item.Parent end
        if item.Type == "ColorPicker" then realSource = item end
        table.insert(Labels.Content, CreateLabel(ContentScroll, item, realSource))
    end
    if State.ItemIndex > #CurrentItems then State.ItemIndex = #CurrentItems end
    UpdateVisuals()
end

for _ in ipairs(MenuData) do
    table.insert(Labels.Tabs, CreateLabel(TabScroll))
end

--// KEYBIND HANDLING (NEW) //--
local function OnF1Activated(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        local currentConfig = _G.BugFarmAPI.GetConfig()
        if currentConfig.Running then
            _G.BugFarmAPI.Resume() -- F1 resumes if paused
            ShowNotification("Bug Farm: Resumed via F1", 1.5)
            -- Update the "Paused" button state in the menu
            for _, item in ipairs(MenuData[1].Items) do
                if item.Name == "Paused" and item.Type == "Button" then
                    item.State = false
                    break
                end
            end
            UpdateVisuals()
        else
            _G.BugFarmAPI.ForceStart() -- F1 starts if stopped
            ShowNotification("Bug Farm: Started via F1", 1.5)
            -- Update the "Enabled" button state in the menu
            for _, item in ipairs(MenuData[1].Items) do
                if item.Name == "Enabled" and item.Type == "Button" then
                    item.State = true
                    break
                end
            end
            UpdateVisuals()
        end
    end
end

local function OnF2Activated(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        local currentConfig = _G.BugFarmAPI.GetConfig()
        if currentConfig.Running and not currentConfig.Paused then
            _G.BugFarmAPI.Pause() -- F2 pauses if running and not paused
            ShowNotification("Bug Farm: Paused via F2", 1.5)
            -- Update the "Paused" button state in the menu
            for _, item in ipairs(MenuData[1].Items) do
                if item.Name == "Paused" and item.Type == "Button" then
                    item.State = true
                    break
                end
            end
        elseif currentConfig.Running and currentConfig.Paused then
            _G.BugFarmAPI.Resume() -- F2 resumes if paused
            ShowNotification("Bug Farm: Resumed via F2", 1.5)
            -- Update the "Paused" button state in the menu
            for _, item in ipairs(MenuData[1].Items) do
                if item.Name == "Paused" and item.Type == "Button" then
                    item.State = false
                    break
                end
            end
        else
            -- If not running, F2 does nothing specific, but could be used to start if desired
            -- For consistency with your request, let's just notify if not running.
            ShowNotification("Bug Farm: Not running", 1.5)
        end
        UpdateVisuals()
    end
end

local function OnF3Activated(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        _G.BugFarmAPI.Stop() -- F3 forces stop
        ShowNotification("Bug Farm: Stopped via F3", 1.5)
        -- Update the "Enabled" and "Paused" button states in the menu
        for _, item in ipairs(MenuData[1].Items) do
            if item.Name == "Enabled" and item.Type == "Button" then
                item.State = false
            elseif item.Name == "Paused" and item.Type == "Button" then
                item.State = false
            end
        end
        UpdateVisuals()
    end
end

-- Bind keys
ContextActionService:BindAction("BugFarmF1", OnF1Activated, false, Enum.KeyCode.F1)
ContextActionService:BindAction("BugFarmF2", OnF2Activated, false, Enum.KeyCode.F2)
ContextActionService:BindAction("BugFarmF3", OnF3Activated, false, Enum.KeyCode.F3)

--// INPUT HANDLING //--
local function ToggleFade(visible)
    local t = visible and 0 or 1
    if MiniIcon then
        TweenService:Create(MiniIcon, TweenInfo.new(0.3), {BackgroundTransparency = t}):Play()
    end
end

local InputData = {Key = nil, Active = false, Timer = 0, CurrentDelay = 0.2}
local function ExecuteInput(key)
    if not ScreenGui or not ScreenGui.Parent then return end
    if State.IsAnimating then return end
    if State.IsCollapsed then
        if key == Enum.KeyCode.Left then
            State.IsCollapsed = false
            ToggleFade(false)
            if TabFrame then
                TweenService:Create(TabFrame, TweenInfo.new(0.3), {Position = LayoutConfig.TabHiddenPos}):Play()
            end
        end
        return
    end
    if key == Enum.KeyCode.Up then
        if State.InTabs then
            State.TabIndex = State.TabIndex - 1
            if State.TabIndex < 1 then State.TabIndex = #MenuData end
        else
            State.ItemIndex = State.ItemIndex - 1
            if State.ItemIndex < 1 then State.ItemIndex = #CurrentItems end
        end
        UpdateVisuals()
    elseif key == Enum.KeyCode.Down then
        if State.InTabs then
            State.TabIndex = State.TabIndex + 1
            if State.TabIndex > #MenuData then State.TabIndex = 1 end
        else
            State.ItemIndex = State.ItemIndex + 1
            if State.ItemIndex > #CurrentItems then State.ItemIndex = 1 end
        end
        UpdateVisuals()
    end
    if not State.InTabs then
        local item = CurrentItems[State.ItemIndex]
        if item and (item.Type == "Slider" or item.Type == "ColorOption") then
            if key == Enum.KeyCode.Right then
                local oldVal = item.Value or 0
                item.Value = (item.Value or 0) + 1
                if item.Value > (item.Max or 100) then item.Value = item.Max or 100 end
                if item.Type == "ColorOption" and item.Parent then
                    item.Parent[item.Name] = item.Value
                end
                -- Handle Pine Tree Distance slider specifically
                if item.Parent and item.Parent.Name == "Pine Tree Distance" and item.Parent.Type == "Slider" then
                     _G.BugFarmAPI.SetConfig({PineTreeApproachDistance = item.Value})
                 end
                if State.AutoSave and oldVal ~= item.Value then
                    task.delay(0.5, function()
                        if State.LastConfig ~= "" then
                            SaveConfig(State.LastConfig)
                        end
                    end)
                end
                UpdateVisuals()
            elseif key == Enum.KeyCode.Left then
                local oldVal = item.Value or 0
                item.Value = (item.Value or 0) - 1
                if item.Value < (item.Min or 0) then item.Value = item.Min or 0 end -- Use Min if defined
                if item.Type == "ColorOption" and item.Parent then
                    item.Parent[item.Name] = item.Value
                end
                -- Handle Pine Tree Distance slider specifically
                if item.Parent and item.Parent.Name == "Pine Tree Distance" and item.Parent.Type == "Slider" then
                     _G.BugFarmAPI.SetConfig({PineTreeApproachDistance = item.Value})
                 end
                if State.AutoSave and oldVal ~= item.Value then
                    task.delay(0.5, function()
                        if State.LastConfig ~= "" then
                            SaveConfig(State.LastConfig)
                        end
                    end)
                end
                UpdateVisuals()
            end
        end
    end
    if State.InTabs then
        if key == Enum.KeyCode.Right then
            State.FileMode = false
            State.SearchMode = false
            State.JustOpenedParent = nil
            RefreshList()
            State.InTabs = false
            if TabFrame then
                TweenService:Create(TabFrame, TweenInfo.new(0.3), {Position = LayoutConfig.TabVisiblePos}):Play()
            end
            if ContentFrame then
                TweenService:Create(ContentFrame, TweenInfo.new(0.3), {Position = LayoutConfig.ContentVisiblePos}):Play()
            end
            UpdateVisuals()
        elseif key == Enum.KeyCode.Left then
            State.IsCollapsed = true
            ToggleFade(true)
            if TabFrame then
                TweenService:Create(TabFrame, TweenInfo.new(0.3), {Position = LayoutConfig.CollapsedPos}):Play()
            end
        end
    end
end

local function TriggerSingleAction(key)
    if State.IsAnimating or not ScreenGui or not ScreenGui.Parent then return end
    local item = State.InTabs and nil or CurrentItems[State.ItemIndex]
    local currentTab = MenuData[State.TabIndex]
    -- Переключение между табами в DoubleTab
    if currentTab and currentTab.Type == "DoubleTab" and not State.InTabs then
        if key == Enum.KeyCode.Right or key == Enum.KeyCode.Left then
            -- Переключаем таб только если не на элементе, который использует стрелки
            if not item or (item.Type ~= "Slider" and item.Type ~= "ColorOption" and
               not (item.Type == "Dropdown" and item.Expanded) and
               not (item.Type == "ComboBox" and item.Expanded) and
               not (item.Type == "ColorPicker" and item.Expanded)) then
                State.InLeftTab = not State.InLeftTab
                State.ItemIndex = 1
                RefreshList()
                return
            end
        end
    end
    if not State.InTabs and item then
        if (item.Type == "Slider" or item.Type == "ColorOption") then
            if key == Enum.KeyCode.Right or key == Enum.KeyCode.Left then
                ExecuteInput(key)
                return
            end
        end
        if key == Enum.KeyCode.Right then
            if item.Type == "Back" then
                if State.FileMode then
                    State.FileMode = false
                    RefreshList()
                elseif State.SearchMode then
                    State.SearchMode = false
                    State.SearchQuery = ""
                    RefreshList()
                else
                    State.InTabs = true
                    if TabFrame then
                        TweenService:Create(TabFrame, TweenInfo.new(0.3), {Position = LayoutConfig.TabHiddenPos}):Play()
                    end
                    if ContentFrame then
                        TweenService:Create(ContentFrame, TweenInfo.new(0.3), {Position = LayoutConfig.ContentHiddenPos}):Play()
                    end
                    UpdateVisuals()
                end
                return
            elseif item.Type == "TabSwitch" then
                -- Переключение таба при нажатии на подсказку
                State.InLeftTab = not State.InLeftTab
                State.ItemIndex = 1
                RefreshList()
                return
            elseif item.Type == "Refresh" then
                RefreshList()
                ShowNotification("List refreshed", 1)
            elseif item.Type == "Button" then
                local oldState = item.State or false
                item.State = not oldState
                if item.Callback then
                    local success, err = pcall(item.Callback, item.State)
                    if not success then
                        warn("[BBSR] Callback error:", err)
                        ShowNotification("Callback error!", 2)
                        item.State = oldState
                    end
                end
                -- Special handling for "Paused" button callback
                if item.Name == "Paused" and item.Type == "Button" then
                     if item.State then
                         _G.BugFarmAPI.Pause() -- Use API to pause if menu says paused
                         ShowNotification("Bug Farm: Paused", 1.5)
                     else
                         _G.BugFarmAPI.Resume() -- Use API to resume if menu says resumed
                         ShowNotification("Bug Farm: Resumed", 1.5)
                     end
                 end
                if State.AutoSave and State.LastConfig ~= "" then
                    task.delay(0.3, function() SaveConfig(State.LastConfig) end)
                end
            elseif item.Type == "ColorPreset" then
                if item.Parent then
                    item.Parent.R = item.R or 255
                    item.Parent.G = item.G or 255
                    item.Parent.B = item.B or 255
                    ShowNotification("Preset: "..tostring(item.Name), 1)
                    RefreshList()
                end
            elseif item.Type == "Dropdown" then
                if item.IsOption then
                    local p = item.Parent
                    if p then
                        p.Value = item.Name or ""
                        State.IsAnimating = true
                        for _, l in ipairs(Labels.Content) do
                            if l.Item and l.Item.Parent == p then
                                TweenService:Create(l.Frame, TweenInfo.new(LayoutConfig.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1,0,0,0)}):Play()
                            end
                        end
                        task.delay(LayoutConfig.AnimSpeed, function()
                            if p then
                                p.Expanded = false
                                if p.Callback then
                                    pcall(p.Callback, item.Name)
                                end
                                State.JustOpenedParent = nil
                                RefreshList()
                                for i, v in ipairs(CurrentItems) do
                                    if v == p then
                                        State.ItemIndex = i
                                        break
                                    end
                                end
                                UpdateVisuals()
                                State.IsAnimating = false
                                if State.AutoSave and State.LastConfig ~= "" then
                                    SaveConfig(State.LastConfig)
                                end
                            end
                        end)
                    end
                else
                    if item.Expanded then
                        State.IsAnimating = true
                        for _, l in ipairs(Labels.Content) do
                            if l.Item and l.Item.Parent == item then
                                TweenService:Create(l.Frame, TweenInfo.new(LayoutConfig.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1,0,0,0)}):Play()
                            end
                        end
                        task.delay(LayoutConfig.AnimSpeed, function()
                            item.Expanded = false
                            State.JustOpenedParent = nil
                            RefreshList()
                            State.IsAnimating = false
                        end)
                    else
                        item.Expanded = true
                        State.JustOpenedParent = item
                        RefreshList()
                    end
                end
                return
            -- Обработка комбобокса
            elseif item.Type == "ComboBox" then
                if item.IsOption then
                    -- Переключение выбора в комбобоксе
                    if item.Parent then
                        ToggleComboBoxOption(item.Parent, item.Name or "")
                        UpdateVisuals()
                    end
                else
                    if item.Expanded then
                        State.IsAnimating = true
                        for _, l in ipairs(Labels.Content) do
                            if l.Item and l.Item.Parent == item then
                                TweenService:Create(l.Frame, TweenInfo.new(LayoutConfig.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1,0,0,0)}):Play()
                            end
                        end
                        task.delay(LayoutConfig.AnimSpeed, function()
                            item.Expanded = false
                            State.JustOpenedParent = nil
                            RefreshList()
                            State.IsAnimating = false
                        end)
                    else
                        item.Expanded = true
                        State.JustOpenedParent = item
                        RefreshList()
                    end
                end
                return
            elseif item.Type == "ColorPicker" then
                if item.Expanded then
                    State.IsAnimating = true
                    for _, l in ipairs(Labels.Content) do
                        if l.Item and l.Item.Parent == item then
                            TweenService:Create(l.Frame, TweenInfo.new(LayoutConfig.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1,0,0,0)}):Play()
                        elseif l.Item == item then
                            TweenService:Create(l.ColorBox, TweenInfo.new(LayoutConfig.AnimSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -20, 0.5, -6)}):Play()
                        end
                    end
                    task.delay(LayoutConfig.AnimSpeed, function()
                        item.Expanded = false
                        State.JustOpenedParent = nil
                        RefreshList()
                        for i, v in ipairs(CurrentItems) do
                            if v == item then
                                State.ItemIndex = i
                                break
                            end
                        end
                        UpdateVisuals()
                        State.IsAnimating = false
                    end)
                else
                    item.Expanded = true
                    State.JustOpenedParent = item
                    RefreshList()
                    for _, l in ipairs(Labels.Content) do
                        if l.Item == item then
                            l.ColorBox.Size = UDim2.new(0, 12, 0, 12)
                            l.ColorBox.Position = UDim2.new(1, -20, 0.5, -6)
                            TweenService:Create(l.ColorBox, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 5, 1, 5)}):Play()
                            break
                        end
                    end
                end
            elseif item.Type == "Action" then
                if item.Action == "Save" then
                    State.IsInputting = true
                    InputFrame.Visible = true
                    InputBox.PlaceholderText = "Config Name..."
                    InputBox.Text = State.LastConfig
                    InputBox:CaptureFocus()
                elseif item.Action == "Load" then
                    State.FileMode = true
                    State.JustOpenedParent = nil
                    RefreshList()
                elseif item.Action == "Search" then
                    State.IsInputting = true
                    InputFrame.Visible = true
                    InputBox.PlaceholderText = "Search items..."
                    InputBox.Text = ""
                    InputBox:CaptureFocus()
                    State.SearchMode = true
                elseif item.Action == "EditBlacklist" then
                    BlacklistFrame.Visible = true
                    BlacklistBox:CaptureFocus()
                    BlacklistBox.Text = table.concat(_G.BugFarmAPI.Blacklist, "\n") -- Use API's blacklist
                elseif item.Action == "ForceStartBugFarm" then
                    _G.BugFarmAPI.ForceStart() -- Use API to force start
                    ShowNotification("Bug Farm Force Started", 2)
                    -- Update the "Enabled" button state in the menu
                    for _, item in ipairs(MenuData[1].Items) do
                        if item.Name == "Enabled" and item.Type == "Button" then
                            item.State = true
                            break
                        end
                    end
                    UpdateVisuals()
                elseif item.Action == "StopBugFarm" then
                    _G.BugFarmAPI.Stop() -- Use API to stop
                    ShowNotification("Bug Farm Stopped", 2)
                    -- Update the "Enabled" and "Paused" button states in the menu
                    for _, item in ipairs(MenuData[1].Items) do
                        if item.Name == "Enabled" and item.Type == "Button" then
                            item.State = false
                        elseif item.Name == "Paused" and item.Type == "Button" then
                            item.State = false
                        end
                    end
                    UpdateVisuals()
                end
            elseif item.Type == "File" then
                LoadConfig(item.Name or "")
                State.FileMode = false
                State.JustOpenedParent = nil
                RefreshList()
            elseif item.Type == "ColorAction" then
                if item.Action == "Copy" then
                    if setclipboard and item.Parent then
                        setclipboard(RGBtoHex(item.Parent.R or 255, item.Parent.G or 255, item.Parent.B or 255))
                        ShowNotification("Copied: "..RGBtoHex(item.Parent.R or 255, item.Parent.G or 255, item.Parent.B or 255), 1.5)
                    end
                elseif item.Action == "Paste" then
                    State.ClipboardMode = true
                    State.IsInputting = true
                    State.TargetPicker = item.Parent
                    InputFrame.Visible = true
                    InputBox.PlaceholderText = "Paste Hex (#RRGGBB)"
                    InputBox.Text = ""
                    InputBox:CaptureFocus()
                end
            end
            UpdateVisuals()
            return
        elseif key == Enum.KeyCode.Left then
            if item.Type == "Back" then
                if State.FileMode then
                    State.FileMode = false
                    State.JustOpenedParent = nil
                    RefreshList()
                elseif State.SearchMode then
                    State.SearchMode = false
                    State.SearchQuery = ""
                    RefreshList()
                else
                    State.InTabs = true
                    State.JustOpenedParent = nil
                    if TabFrame then
                        TweenService:Create(TabFrame, TweenInfo.new(0.3), {Position = LayoutConfig.TabHiddenPos}):Play()
                    end
                    if ContentFrame then
                        TweenService:Create(ContentFrame, TweenInfo.new(0.3), {Position = LayoutConfig.ContentHiddenPos}):Play()
                    end
                    UpdateVisuals()
                end
                return
            elseif not (item.Type == "Slider" or item.Type == "ColorOption") then
                State.InTabs = true
                State.JustOpenedParent = nil
                if TabFrame then
                    TweenService:Create(TabFrame, TweenInfo.new(0.3), {Position = LayoutConfig.TabHiddenPos}):Play()
                end
                if ContentFrame then
                    TweenService:Create(ContentFrame, TweenInfo.new(0.3), {Position = LayoutConfig.ContentHiddenPos}):Play()
                end
                UpdateVisuals()
                return
            end
        end
    end
    ExecuteInput(key)
end

-- Input processing
local RS_Connection = RunService.RenderStepped:Connect(function(dt)
    if not ScreenGui or not ScreenGui.Parent then return end
    if InputData.Active and InputData.Key then
        InputData.Timer = InputData.Timer + dt
        if InputData.Timer > InputData.CurrentDelay then
            InputData.Timer = 0
            ExecuteInput(InputData.Key)
            InputData.CurrentDelay = math.max(0.01, InputData.CurrentDelay * 0.85)
        end
    else
        InputData.Timer = 0
        InputData.CurrentDelay = 0.2
    end
end)
table.insert(Connections, RS_Connection)

-- Input Box Logic
local IB_Connection = InputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local t = InputBox.Text or ""
        if #t > 0 then
            if State.ClipboardMode and State.TargetPicker then
                local r,g,b = HexToRGB(t)
                if r then
                    State.TargetPicker.R = r
                    State.TargetPicker.G = g
                    State.TargetPicker.B = b
                    ShowNotification("Color pasted!", 1.5)
                    RefreshList()
                else
                    ShowNotification("Invalid hex format!", 2)
                    InputBox.Text = ""
                    InputBox:CaptureFocus()
                    return
                end
            elseif State.SearchMode then
                State.SearchQuery = t
                State.ItemIndex = 1
                RefreshList()
            else
                SaveConfig(t)
            end
        end
    end
    State.ClipboardMode = false
    State.TargetPicker = nil
    if not State.SearchMode then
        InputBox.Text = ""
        InputFrame.Visible = false
        State.IsInputting = false
    end
end)
table.insert(Connections, IB_Connection)

-- Blacklist Box Logic
local BlacklistConnection = BlacklistBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local text = BlacklistBox.Text
        local lines = {}
        for line in text:gmatch("[^\r\n]+") do
            line = line:gsub("%s+", ""):lower()
            if line ~= "" then
                table.insert(lines, line)
            end
        end
        -- Update the API's blacklist
        _G.BugFarmAPI.Blacklist = lines
        -- Also update the core's internal table if needed, or just rely on the API's table
        _G.BugFarmAPI.SetConfig({Blacklist = lines})
        ShowNotification("Blacklist updated (" .. #lines .. " mobs)", 2)
    end
    BlacklistFrame.Visible = false
end)
table.insert(Connections, BlacklistConnection)

local function SetControls(a)
    if a then
        ContextActionService:BindActionAtPriority("MenuSink", function()
            return Enum.ContextActionResult.Sink
        end, false, 3000, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)
    else
        ContextActionService:UnbindAction("MenuSink")
    end
end

-- Menu toggle (Right Ctrl)
local function ToggleMenuVisibility()
    State.MenuVisible = not State.MenuVisible
    if State.MenuVisible then
        if TabFrame then TabFrame.Visible = true end
        if ContentFrame then ContentFrame.Visible = true end
        if MiniIcon then MiniIcon.Visible = true end
        SetControls(true)
        ShowNotification("Menu: ON", 1)
    else
        if TabFrame then TabFrame.Visible = false end
        if ContentFrame then ContentFrame.Visible = false end
        if MiniIcon then MiniIcon.Visible = false end
        if InputFrame then InputFrame.Visible = false end
        if BlacklistFrame then BlacklistFrame.Visible = false end
        State.IsInputting = false
        SetControls(false)
        ShowNotification("Menu: OFF", 1)
    end
end

local UIS_Began = UserInputService.InputBegan:Connect(function(i,g)
    if not ScreenGui or not ScreenGui.Parent then return end
    -- Toggle menu with Right Ctrl
    if i.KeyCode == Enum.KeyCode.RightControl then
        ToggleMenuVisibility()
        return
    end
    if not State.MenuVisible then return end
    if State.IsInputting then
        if i.KeyCode == Enum.KeyCode.Escape then
            InputBox:ReleaseFocus()
            if State.SearchMode then
                State.SearchMode = false
                State.SearchQuery = ""
                RefreshList()
            end
        end
        return
    end
    -- Close blacklist editor with Escape
    if BlacklistFrame.Visible then
        if i.KeyCode == Enum.KeyCode.Escape then
            BlacklistBox:ReleaseFocus()
            BlacklistFrame.Visible = false
        end
        return
    end
    local k = i.KeyCode
    if k==Enum.KeyCode.Up or k==Enum.KeyCode.Down or k==Enum.KeyCode.Left or k==Enum.KeyCode.Right then
        InputData.Key=k
        InputData.Active=true
        TriggerSingleAction(k)
    end
end)
table.insert(Connections, UIS_Began)

local UIS_Ended = UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == InputData.Key then
        InputData.Active = false
        InputData.Key = nil
    end
end)
table.insert(Connections, UIS_Ended)

--// INITIALIZE //--
-- Wait for API to be available
repeat task.wait() until _G.BugFarmAPI
RefreshList()
SetControls(true)
UpdateVisuals()

-- Auto-load default config if exists
task.delay(0.5, function()
    if isfile and isfile(ConfigFolder.."/default.json") then
        LoadConfig("default.json")
    end
end)

ShowNotification("BBSR v9.0 Bug Farm Menu loaded | Right Ctrl to toggle | F1: Start/Resume, F2: Pause/Resume, F3: Stop", 3)
print("[BugFarmMenu] Loaded. Waiting for API...")
