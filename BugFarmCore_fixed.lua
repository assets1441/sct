-- BugFarmCore.lua
--// SERVICES //--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService") -- Для JSON

--// BUG FARM STATE & CONFIG //--
local BugFarm = {
    Enabled = false, -- Устанавливается через меню, не запускает цикл
    Running = false, -- Устанавливается при запуске цикла
    Paused = false,  -- Устанавливается при паузе цикла
    Blacklist = {
        "coconutcrab", "commandochick", "kingbeetle", "stumpsnail",
        "tunnelbear", "cavemonster", "aphid", "vicious", "mondochick", "cavemonster1"
    },
    MobScanRadius = 80,
    LootCollectDelay = 1.5,
    WalkSpeedDuringLoot = 80,
    JumpDodgeEnabled = true,
    AutoConvertPollen = true,
    CooldownMultiplier = 1.0,
    AutoLoot = true,
    CheckInterval = 5,
    -- ShowNotifications = true, -- Убрана настройка уведомлений
    PineTreeApproachDistance = 20 -- Используется для слайдера
}

local FieldsData = {}
local SpawnerCooldownCache = {}
local BugFarmThread = nil

--// MAPPINGS //--
local FieldNameMap = {
    ["Sunflower Field"]     = "FP1",
    ["Dandelion Field"]     = "FP2",
    ["Mushroom Field"]      = "FP3",
    ["Blue Flower Field"]   = "FP4",
    ["Clover Field"]        = "FP5",
    ["Spider Field"]        = "FP6",
    ["Strawberry Field"]    = "FP7",
    ["Bamboo Field"]        = "FP8",
    ["Pineapple Patch"]     = "FP9",
    ["Cactus Field"]        = "FP10",
    ["Pumpkin Patch"]       = "FP11",
    ["Pine Tree Forest"]    = "FP12",
    ["Rose Field"]          = "FP13",
    ["Mountain Top Field"]  = "FP14",
    ["Ant Field"]           = "FP15",
    ["Stump Field"]         = "FP16",
    ["Coconut Field"]       = "FP17",
    ["Pepper Patch"]        = "FP18"
}

local SpawnerGroups = {
    { spawners = {"Ladybug Bush"}, field = "Clover Field" },
    { spawners = {"Spider Cave"}, field = "Spider Field" },
    { spawners = {"Rhino Cave 1"}, field = "Bamboo Field" },
    { spawners = {"Rhino Cave 2", "Rhino Cave 3"}, field = "Bamboo Field" },
    { spawners = {"RoseBush", "RoseBush2"}, field = "Rose Field" },
    { spawners = {"Ladybug Bush 2", "Ladybug Bush 3"}, field = "Strawberry Field" },
    { spawners = {"ForestMantis1", "ForestMantis2"}, field = "Pine Tree Forest" },
    { spawners = {"Ladybug Bush", "Rhino Bush"}, field = "Blue Flower Field" },
    { spawners = {"WerewolfCave"}, field = "Cactus Field" },
    { spawners = {"PineappleMantis1", "PineappleBeetle"}, field = "Pineapple Patch" },
    { spawners = {"MushroomBush"}, field = "Mushroom Field" }
}

--// HELPERS //--
local function getRoot()
    local Character = Players.LocalPlayer.Character
    return Character and Character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local Character = Players.LocalPlayer.Character
    return Character and Character:FindFirstChild("Humanoid")
end

--// MAIN FUNCTIONS //--
local function CalculateFields()
    local tempBounds = {}
    for _, flower in pairs(Workspace.Flowers:GetChildren()) do
        local split = flower.Name:split("-")
        local fpID = split[1]
        if fpID and fpID:sub(1,2) == "FP" then
            if not tempBounds[fpID] then
                tempBounds[fpID] = {min = flower.Position, max = flower.Position}
            else
                local cMin = tempBounds[fpID].min
                local cMax = tempBounds[fpID].max
                tempBounds[fpID].min = Vector3.new(
                    math.min(cMin.X, flower.Position.X),
                    math.min(cMin.Y, flower.Position.Y),
                    math.min(cMin.Z, flower.Position.Z)
                )
                tempBounds[fpID].max = Vector3.new(
                    math.max(cMax.X, flower.Position.X),
                    math.max(cMax.Y, flower.Position.Y),
                    math.max(cMax.Z, flower.Position.Z)
                )
            end
        end
    end
    for name, id in pairs(FieldNameMap) do
        if tempBounds[id] then
            local min = tempBounds[id].min
            local max = tempBounds[id].max
            local bounds = {
                min = min - Vector3.new(2, 5, 2),
                max = max + Vector3.new(2, 50, 2)
            }
            FieldsData[name] = {
                Center = (min + max) / 2 + Vector3.new(0, 5, 0),
                Bounds = bounds,
                ID = id
            }
        end
    end
end

local function IsInField(position, fieldName)
    local data = FieldsData[fieldName]
    if not data then return false end
    local min = data.Bounds.min
    local max = data.Bounds.max
    return (position.X >= min.X and position.X <= max.X) and (position.Z >= min.Z and position.Z <= max.Z)
end

local function IsSpawnerReady(spawnerName)
    if SpawnerCooldownCache[spawnerName] and tick() < SpawnerCooldownCache[spawnerName] then
        return false
    end
    local spawner = Workspace.MonsterSpawners:FindFirstChild(spawnerName)
    if not spawner then return false end
    local timerLabel = nil
    for _, obj in pairs(spawner:GetDescendants()) do
        if obj.Name == "TimerLabel" and obj:IsA("TextLabel") then
            timerLabel = obj
            break
        end
    end
    if timerLabel then
        if timerLabel.Visible and timerLabel.Text ~= "" and timerLabel.Text ~= "0:00" then
            return false
        end
    end
    return true
end

local function SetManualCooldown(spawnerName, duration)
    -- Use the current multiplier from BugFarm table
    SpawnerCooldownCache[spawnerName] = tick() + (duration * BugFarm.CooldownMultiplier)
end

local function TeleportTo(position)
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(position)
    end
end

local function CheckAndConvertPollen()
    -- Read setting directly when function is called
    if not BugFarm.AutoConvertPollen then return end
    local coreStats = Players.LocalPlayer:FindFirstChild("CoreStats")
    if coreStats then
        local pollen = coreStats.Pollen.Value
        local capacity = coreStats.Capacity.Value
        if pollen > (capacity / 4) then
            -- ShowNotification("Converting pollen...", 1) -- Notification logic moved to menu
            local hives = Workspace.Honeycombs:GetChildren()
            for _, hive in pairs(hives) do
                if hive.Owner.Value == Players.LocalPlayer then
                    local platform = hive.SpawnPos.Value
                    TeleportTo(platform.Position + Vector3.new(0, 5, 0))
                    break
                end
            end
            repeat
                task.wait(1)
                pollen = coreStats.Pollen.Value
                -- Check if still running inside the loop
                if not BugFarm.Running then break end
            until pollen <= 0 or not BugFarm.Running
            -- if BugFarm.Running then -- Only show notification if still running
            --     ShowNotification("Pollen converted", 1) -- Notification logic moved to menu
            -- end
        end
    end
end

local function HandleCombat(currentFieldName)
    local root = getRoot()
    local hum = getHumanoid()
    if not root or not hum then return false end
    local lastJumpTime = 0
    local mobStates = {}
    local startTime = tick()
    local targetFound = false
    local maxWaitTime = 2
    while BugFarm.Running and not BugFarm.Paused do -- ИЗМЕНЕНО: Проверка Paused внутри цикла боя
        -- Read setting directly when entering combat check
        local scanRadius = BugFarm.MobScanRadius
        local jumpDodgeEnabled = BugFarm.JumpDodgeEnabled

        local activeMobs = {}
        local anyMobAlive = false
        for _, mob in pairs(Workspace.Monsters:GetChildren()) do
            local isBlacklisted = false
            for _, bl in pairs(BugFarm.Blacklist) do
                if string.find(string.lower(mob.Name), bl) then isBlacklisted = true break end
            end
            if not isBlacklisted and mob:FindFirstChild("Head") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                local dist = (mob.Head.Position - root.Position).Magnitude
                if dist < scanRadius then -- Use the current setting
                    table.insert(activeMobs, mob)
                    anyMobAlive = true
                end
            end
        end
        if anyMobAlive then
            targetFound = true
            -- ИЗМЕНЕНАЯ ЛОГИКА ДЛЯ Pine Tree Forest
            if currentFieldName == "Pine Tree Forest" then
                local closestMob = nil
                local minDst = 9999
                for _, m in pairs(activeMobs) do
                    local d = (m.Head.Position - root.Position).Magnitude
                    if d < minDst then
                        minDst = d
                        closestMob = m
                    end
                end
                if closestMob then
                    local mobPos = closestMob.Head.Position
                    local playerPos = root.Position
                    local directionToMob = (mobPos - playerPos).Unit -- Направление к мобу
                    -- Вычисляем точку на нужном расстоянии от моба (но не за ним)
                    -- Формула: позиция_моба - направление_к_мобу * расстояние
                    local desiredDistance = BugFarm.PineTreeApproachDistance -- Используем настройку
                    local approachPoint = mobPos - directionToMob * desiredDistance

                    -- Двигаемся к рассчитанной точке
                    hum:MoveTo(approachPoint)

                    -- Ждём немного или пока не будет рядом с точкой
                    local approachStartTime = tick()
                    while (root.Position - approachPoint).Magnitude > 5 and (tick() - approachStartTime) < 1.5 and BugFarm.Running and not BugFarm.Paused do -- ИЗМЕНЕНО: Проверка Paused
                        task.wait(0.1)
                    end

                    -- Теперь отбегаем от моба
                    -- Вычисляем точку "за" игроком, противоположно мобу
                    local retreatPoint = playerPos - directionToMob * 10 -- Отбегаем на 10 стадий назад
                    hum:MoveTo(retreatPoint)

                    -- Ждём немного или пока не будет рядом с точкой отступления
                    local retreatStartTime = tick()
                    while (root.Position - retreatPoint).Magnitude > 3 and (tick() - retreatStartTime) < 1 and BugFarm.Running and not BugFarm.Paused do -- ИЗМЕНЕНО: Проверка Paused
                        task.wait(0.1)
                    end
                end
            else
                -- Стандартное поведение для других полей (если нужно)
                -- (Оставьте пустым, если не нужно ничего делать)
            end
        else
            if targetFound then
                -- ShowNotification("Mobs killed", 1) -- Notification logic moved to menu
                return true
            else
                if (tick() - startTime) > maxWaitTime then
                    return false
                end
            end
        end
        if jumpDodgeEnabled then -- Use the current setting
            for _, mob in pairs(activeMobs) do
                local mobPos = mob.Head.Position
                if not mobStates[mob] then
                    mobStates[mob] = {lastPos = mobPos, lastCheck = tick()}
                end
                local state = mobStates[mob]
                local timeDelta = tick() - state.lastCheck
                if timeDelta > 0.1 then
                    local moveDist = (mobPos - state.lastPos).Magnitude
                    local speed = moveDist / timeDelta
                    local distToPlayer = (mobPos - root.Position).Magnitude
                    if distToPlayer < 50 and speed < 1 and (tick() - lastJumpTime > 2) then
                        hum.Jump = true
                        lastJumpTime = tick()
                    end
                    state.lastPos = mobPos
                    state.lastCheck = tick()
                end
            end
        end
        task.wait(0.1)
    end
    return false
end

local function CollectLoot(fieldName)
    -- Read setting directly when function is called
    if not BugFarm.AutoLoot then return end
    local lootDelay = BugFarm.LootCollectDelay
    local walkSpeed = BugFarm.WalkSpeedDuringLoot

    -- ShowNotification("Collecting loot...", 1) -- Notification logic moved to menu
    task.wait(lootDelay) -- Use the current setting
    local hum = getHumanoid()
    local root = getRoot()
    if not hum or not root then return end
    local oldWalkSpeed = hum.WalkSpeed
    hum.WalkSpeed = walkSpeed -- Use the current setting
    local validTokens = {}
    for _, token in pairs(Workspace.Collectibles:GetChildren()) do
        if IsInField(token.Position, fieldName) then
            local heightDiff = token.Position.Y - root.Position.Y
            local isExactly07 = math.abs(token.Transparency - 0.7) < 0.0001
            if heightDiff <= 4 and token.Transparency < 1 and not isExactly07 then
                table.insert(validTokens, token)
            end
        end
    end
    while #validTokens > 0 and BugFarm.Running and not BugFarm.Paused do -- ИЗМЕНЕНО: Проверка Paused
        table.sort(validTokens, function(a, b)
            if not a.Parent or not b.Parent then return false end
            local distA = (a.Position - root.Position).Magnitude
            local distB = (b.Position - root.Position).Magnitude
            return distA < distB
        end)
        local targetToken = validTokens[1]
        table.remove(validTokens, 1)
        if targetToken and targetToken.Parent then
            hum:MoveTo(targetToken.Position)
            local moveStartTime = tick()
            local collected = false
            while not collected and tick() - moveStartTime < 2 and BugFarm.Running and not BugFarm.Paused do -- ИЗМЕНЕНО: Проверка Paused
                if not targetToken.Parent then
                    collected = true
                    break
                end
                local dist = (root.Position - targetToken.Position).Magnitude
                if dist < 3.5 then
                    collected = true
                end
                task.wait()
            end
        end
        for i = #validTokens, 1, -1 do
            if not validTokens[i].Parent then
                table.remove(validTokens, i)
            end
        end
    end
    hum.WalkSpeed = oldWalkSpeed
    -- if BugFarm.Running then -- Only show notification if still running
    --     ShowNotification("Loot collected", 1) -- Notification logic moved to menu
    -- end
end

local function BugFarmMainLoop()
    if BugFarm.Running then return end
    BugFarm.Running = true
    BugFarm.Paused = false -- Убедиться, что сброшено при старте
    CalculateFields()
    -- ShowNotification("Bug Farm Started", 2) -- Notification logic moved to menu
    while BugFarm.Running and BugFarm.Enabled and not BugFarm.Paused do -- ИЗМЕНЕНО: Добавлена проверка Paused в основной цикл
        pcall(function()
            CheckAndConvertPollen()
            local farmedSomething = false
            for _, group in pairs(SpawnerGroups) do
                local readySpawners = 0
                local spawnersInGroup = {}
                for _, spawnerName in pairs(group.spawners) do
                    if IsSpawnerReady(spawnerName) then
                        readySpawners = readySpawners + 1
                        table.insert(spawnersInGroup, spawnerName)
                    end
                end
                if readySpawners > 0 then
                    local fieldName = group.field
                    local fieldData = FieldsData[fieldName]
                    if fieldData then
                        -- ShowNotification("Farming: " .. fieldName, 2) -- Notification logic moved to menu
                        TeleportTo(fieldData.Center)
                        farmedSomething = true
                        task.wait(0.5)
                        -- HandleCombat will now read current settings
                        local killedMobs = HandleCombat(fieldName)
                        if killedMobs then
                            for _, sName in pairs(spawnersInGroup) do
                                -- SetManualCooldown will now use current multiplier
                                SetManualCooldown(sName, 45)
                            end
                            -- CollectLoot will now read current settings
                            CollectLoot(fieldName)
                            task.wait(1)
                        else
                            for _, sName in pairs(spawnersInGroup) do
                                SetManualCooldown(sName, 10)
                            end
                        end
                    end
                end
            end
            if not farmedSomething then
                -- Read CheckInterval setting here before waiting
                local checkInterval = BugFarm.CheckInterval
                task.wait(checkInterval)
            end
        end)
        task.wait(0.5)
    end
    -- Цикл завершится по одной из причин:
    -- 1. BugFarm.Enabled = false (Stop)
    -- 2. BugFarm.Paused = true (Pause)
    -- 3. BugFarm.Running = false (ошибка или другое)
    -- Если цикл завершился НЕ из-за паузы, значит остановлен окончательно.
    if not BugFarm.Paused then
        BugFarm.Running = false
        BugFarm.Enabled = false -- Также сбрасываем Enabled при полной остановке
        -- ShowNotification("Bug Farm Stopped", 2) -- Notification logic moved to menu
    else
        -- ShowNotification("Bug Farm Paused", 2) -- Можно добавить уведомление о паузе
    end
end

function StartBugFarm() -- Вспомогательная функция, не используется напрямую через F1
    if BugFarm.Running then return end
    BugFarmThread = coroutine.create(BugFarmMainLoop)
    coroutine.resume(BugFarmThread)
end

function StopBugFarm() -- ForceStop
    BugFarm.Paused = false -- Снимаем паузу при остановке
    BugFarm.Running = false
    BugFarm.Enabled = false
    -- ShowNotification("Bug Farm Force Stopped", 2) -- Notification logic moved to menu
end

function PauseBugFarm()
    if BugFarm.Running and not BugFarm.Paused then
        BugFarm.Paused = true
        -- ShowNotification("Bug Farm Paused", 2) -- Notification logic moved to menu
    end
end

function ResumeBugFarm()
    if BugFarm.Running and BugFarm.Paused then
        BugFarm.Paused = false
        -- ShowNotification("Bug Farm Resumed", 2) -- Notification logic moved to menu
    end
end

function ForceStartBugFarm() -- F1 запускает через эту функцию, если Enabled = true
    if BugFarm.Enabled and not BugFarm.Running then
        StartBugFarm()
    end
end

--// API CREATION //--
local BugFarmAPI = {
    Start = StartBugFarm,
    Stop = StopBugFarm,
    Pause = PauseBugFarm,
    Resume = ResumeBugFarm,
    ForceStart = ForceStartBugFarm,
    -- For updating settings from menu
    SetConfig = function(newSettings)
        for key, value in pairs(newSettings) do
            if BugFarm[key] ~= nil then
                BugFarm[key] = value
            end
        end
    end,
    -- For getting current settings
    GetConfig = function() return BugFarm end,
    -- Expose Blacklist for direct manipulation if needed by menu
    Blacklist = BugFarm.Blacklist,
    -- Expose FieldsData if menu needs it
    FieldsData = FieldsData,
    -- Expose other potentially useful functions/vars
    CalculateFields = CalculateFields,
    IsSpawnerReady = IsSpawnerReady,
    -- Add any other functions you might want the menu to call directly
}

-- Store the API in _G
_G.BugFarmAPI = BugFarmAPI

-- Also set up a backup mechanism to restore the API if it gets lost
spawn(function()
    while true do
        task.wait(5) -- Check every 5 seconds
        if not _G.BugFarmAPI then
            _G.BugFarmAPI = BugFarmAPI
            print("[BugFarmCore] API restored after loss")
        end
    end
end)

print("[BugFarmCore] Loaded. API available at _G.BugFarmAPI")