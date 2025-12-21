--[[
Отчет по изменениям:
1.  Найден и добавлен недостающий `end` для закрытия блока `if root then ... end` внутри функции `TeleportTo`.
    Именно эта синтаксическая ошибка приводила к сбою компиляции всего файла.
2.  Сохранена модульная структура (возврат таблицы API в конце), так как это самая надежная архитектура.
]]

--// SERVICES //--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService") -- Для JSON

--// BUG FARM STATE & CONFIG //--
local BugFarm = {
    Enabled = false, Running = false, Paused = false,
    Blacklist = {
        "coconutcrab", "commandochick", "kingbeetle", "stumpsnail",
        "tunnelbear", "cavemonster", "aphid", "vicious", "mondochick", "cavemonster1"
    },
    MobScanRadius = 80, LootCollectDelay = 1.5, WalkSpeedDuringLoot = 80, JumpDodgeEnabled = true,
    AutoConvertPollen = true, CooldownMultiplier = 1.0, AutoLoot = true, CheckInterval = 5,
    PineTreeApproachDistance = 20
}

local FieldsData = {}
local SpawnerCooldownCache = {}
local BugFarmThread = nil

--// MAPPINGS //--
local FieldNameMap = {
    ["Sunflower Field"] = "FP1", ["Dandelion Field"] = "FP2", ["Mushroom Field"] = "FP3",
    ["Blue Flower Field"] = "FP4", ["Clover Field"] = "FP5", ["Spider Field"] = "FP6",
    ["Strawberry Field"] = "FP7", ["Bamboo Field"] = "FP8", ["Pineapple Patch"] = "FP9",
    ["Cactus Field"] = "FP10", ["Pumpkin Patch"] = "FP11", ["Pine Tree Forest"] = "FP12",
    ["Rose Field"] = "FP13", ["Mountain Top Field"] = "FP14", ["Ant Field"] = "FP15",
    ["Stump Field"] = "FP16", ["Coconut Field"] = "FP17", ["Pepper Patch"] = "FP18"
}

local SpawnerGroups = {
    { spawners = {"Ladybug Bush"}, field = "Clover Field" }, { spawners = {"Spider Cave"}, field = "Spider Field" },
    { spawners = {"Rhino Cave 1"}, field = "Bamboo Field" }, { spawners = {"Rhino Cave 2", "Rhino Cave 3"}, field = "Bamboo Field" },
    { spawners = {"RoseBush", "RoseBush2"}, field = "Rose Field" }, { spawners = {"Ladybug Bush 2", "Ladybug Bush 3"}, field = "Strawberry Field" },
    { spawners = {"ForestMantis1", "ForestMantis2"}, field = "Pine Tree Forest" }, { spawners = {"Ladybug Bush", "Rhino Bush"}, field = "Blue Flower Field" },
    { spawners = {"WerewolfCave"}, field = "Cactus Field" }, { spawners = {"PineappleMantis1", "PineappleBeetle"}, field = "Pineapple Patch" },
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
            if not tempBounds[fpID] then tempBounds[fpID] = {min = flower.Position, max = flower.Position}
            else
                local cMin, cMax = tempBounds[fpID].min, tempBounds[fpID].max
                tempBounds[fpID].min = Vector3.new(math.min(cMin.X, flower.Position.X), math.min(cMin.Y, flower.Position.Y), math.min(cMin.Z, flower.Position.Z))
                tempBounds[fpID].max = Vector3.new(math.max(cMax.X, flower.Position.X), math.max(cMax.Y, flower.Position.Y), math.max(cMax.Z, flower.Position.Z))
            end
        end
    end
    for name, id in pairs(FieldNameMap) do
        if tempBounds[id] then
            local min, max = tempBounds[id].min, tempBounds[id].max
            FieldsData[name] = { Center = (min + max) / 2 + Vector3.new(0, 5, 0), Bounds = {min = min - Vector3.new(2, 5, 2), max = max + Vector3.new(2, 50, 2)}, ID = id }
        end
    end
end

local function IsInField(position, fieldName)
    local data = FieldsData[fieldName]
    if not data then return false end
    local min, max = data.Bounds.min, data.Bounds.max
    return (position.X >= min.X and position.X <= max.X) and (position.Z >= min.Z and position.Z <= max.Z)
end

local function IsSpawnerReady(spawnerName)
    if SpawnerCooldownCache[spawnerName] and tick() < SpawnerCooldownCache[spawnerName] then return false end
    local spawner = Workspace.MonsterSpawners:FindFirstChild(spawnerName)
    if not spawner then return false end
    local timerLabel = nil
    for _, obj in pairs(spawner:GetDescendants()) do
        if obj.Name == "TimerLabel" and obj:IsA("TextLabel") then timerLabel = obj; break end
    end
    if timerLabel and timerLabel.Visible and timerLabel.Text ~= "" and timerLabel.Text ~= "0:00" then return false end
    return true
end

local function SetManualCooldown(spawnerName, duration)
    SpawnerCooldownCache[spawnerName] = tick() + (duration * BugFarm.CooldownMultiplier)
end

local function TeleportTo(position)
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(position)
    end -- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<- ИСПРАВЛЕНИЕ ЗДЕСЬ: ДОБАВЛЕН НЕДОСТАЮЩИЙ 'end'
end

local function CheckAndConvertPollen()
    if not BugFarm.AutoConvertPollen then return end
    local coreStats = Players.LocalPlayer:FindFirstChild("CoreStats")
    if coreStats then
        local pollen, capacity = coreStats.Pollen.Value, coreStats.Capacity.Value
        if pollen > (capacity / 4) then
            for _, hive in pairs(Workspace.Honeycombs:GetChildren()) do
                if hive.Owner.Value == Players.LocalPlayer then TeleportTo(hive.SpawnPos.Value.Position + Vector3.new(0, 5, 0)); break end
            end
            repeat task.wait(1); pollen = coreStats.Pollen.Value until pollen <= 0 or not BugFarm.Running
        end
    end
end

local function HandleCombat(currentFieldName)
    local root, hum = getRoot(), getHumanoid()
    if not root or not hum then return false end
    local lastJumpTime, mobStates, startTime, targetFound, maxWaitTime = 0, {}, tick(), false, 2
    while BugFarm.Running and not BugFarm.Paused do
        local scanRadius, jumpDodgeEnabled = BugFarm.MobScanRadius, BugFarm.JumpDodgeEnabled
        local activeMobs, anyMobAlive = {}, false
        for _, mob in pairs(Workspace.Monsters:GetChildren()) do
            local isBlacklisted = false
            for _, bl in pairs(BugFarm.Blacklist) do if string.find(string.lower(mob.Name), bl) then isBlacklisted = true; break end end
            if not isBlacklisted and mob:FindFirstChild("Head") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                if (mob.Head.Position - root.Position).Magnitude < scanRadius then table.insert(activeMobs, mob); anyMobAlive = true end
            end
        end
        if anyMobAlive then
            targetFound = true
            if currentFieldName == "Pine Tree Forest" then
                local closestMob, minDst = nil, 9999
                for _, m in pairs(activeMobs) do local d = (m.Head.Position - root.Position).Magnitude; if d < minDst then minDst = d; closestMob = m end end
                if closestMob then
                    local mobPos, playerPos = closestMob.Head.Position, root.Position
                    local directionToMob = (mobPos - playerPos).Unit
                    local approachPoint = mobPos - directionToMob * BugFarm.PineTreeApproachDistance
                    hum:MoveTo(approachPoint)
                    local approachStartTime = tick()
                    while (root.Position - approachPoint).Magnitude > 5 and (tick() - approachStartTime) < 1.5 and BugFarm.Running and not BugFarm.Paused do task.wait(0.1) end
                    local retreatPoint = root.Position - directionToMob * 10
                    hum:MoveTo(retreatPoint)
                    local retreatStartTime = tick()
                    while (root.Position - retreatPoint).Magnitude > 3 and (tick() - retreatStartTime) < 1 and BugFarm.Running and not BugFarm.Paused do task.wait(0.1) end
                end
            end
        else
            if targetFound then return true
            elseif (tick() - startTime) > maxWaitTime then return false end
        end
        if jumpDodgeEnabled then
            for _, mob in pairs(activeMobs) do
                local mobPos = mob.Head.Position
                if not mobStates[mob] then mobStates[mob] = {lastPos = mobPos, lastCheck = tick()} end
                local state = mobStates[mob]; local timeDelta = tick() - state.lastCheck
                if timeDelta > 0.1 then
                    local speed = (mobPos - state.lastPos).Magnitude / timeDelta
                    if (mobPos - root.Position).Magnitude < 50 and speed < 1 and (tick() - lastJumpTime > 2) then hum.Jump = true; lastJumpTime = tick() end
                    state.lastPos = mobPos; state.lastCheck = tick()
                end
            end
        end
        task.wait(0.1)
    end
    return false
end

local function CollectLoot(fieldName)
    if not BugFarm.AutoLoot then return end
    task.wait(BugFarm.LootCollectDelay)
    local hum, root = getHumanoid(), getRoot()
    if not hum or not root then return end
    local oldWalkSpeed = hum.WalkSpeed; hum.WalkSpeed = BugFarm.WalkSpeedDuringLoot
    local validTokens = {}
    for _, token in pairs(Workspace.Collectibles:GetChildren()) do
        if IsInField(token.Position, fieldName) then
            if token.Position.Y - root.Position.Y <= 4 and token.Transparency < 1 and not (math.abs(token.Transparency - 0.7) < 0.0001) then table.insert(validTokens, token) end
        end
    end
    while #validTokens > 0 and BugFarm.Running and not BugFarm.Paused do
        table.sort(validTokens, function(a, b) if not a.Parent or not b.Parent then return false end; return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude end)
        local targetToken = validTokens[1]; table.remove(validTokens, 1)
        if targetToken and targetToken.Parent then
            hum:MoveTo(targetToken.Position); local moveStartTime, collected = tick(), false
            while not collected and tick() - moveStartTime < 2 and BugFarm.Running and not BugFarm.Paused do
                if not targetToken.Parent or (root.Position - targetToken.Position).Magnitude < 3.5 then collected = true; break end
                task.wait()
            end
        end
        for i = #validTokens, 1, -1 do if not validTokens[i].Parent then table.remove(validTokens, i) end end
    end
    hum.WalkSpeed = oldWalkSpeed
end

local function BugFarmMainLoop()
    if BugFarm.Running then return end
    BugFarm.Running = true; BugFarm.Paused = false; CalculateFields()
    while BugFarm.Running and BugFarm.Enabled and not BugFarm.Paused do
        pcall(function()
            CheckAndConvertPollen()
            local farmedSomething = false
            for _, group in pairs(SpawnerGroups) do
                if not BugFarm.Running or BugFarm.Paused then break end
                local readySpawners, spawnersInGroup = 0, {}
                for _, spawnerName in pairs(group.spawners) do if IsSpawnerReady(spawnerName) then readySpawners = readySpawners + 1; table.insert(spawnersInGroup, spawnerName) end end
                if readySpawners > 0 then
                    local fieldName, fieldData = group.field, FieldsData[group.field]
                    if fieldData then
                        TeleportTo(fieldData.Center); farmedSomething = true; task.wait(0.5)
                        if HandleCombat(fieldName) then
                            for _, sName in pairs(spawnersInGroup) do SetManualCooldown(sName, 45) end
                            CollectLoot(fieldName); task.wait(1)
                        else
                            for _, sName in pairs(spawnersInGroup) do SetManualCooldown(sName, 10) end
                        end
                    end
                end
            end
            if not farmedSomething then task.wait(BugFarm.CheckInterval) end
        end)
        task.wait(0.5)
    end
    if not BugFarm.Paused then BugFarm.Running = false; BugFarm.Enabled = false end
end

local function StartBugFarm()
    if BugFarm.Running then return end
    BugFarmThread = coroutine.create(BugFarmMainLoop); coroutine.resume(BugFarmThread)
end

local function StopBugFarm()
    BugFarm.Paused = false; BugFarm.Running = false; BugFarm.Enabled = false
end

local function PauseBugFarm()
    if BugFarm.Running and not BugFarm.Paused then BugFarm.Paused = true end
end

local function ResumeBugFarm()
    if BugFarm.Running and BugFarm.Paused then
        BugFarm.Paused = false
        if coroutine.status(BugFarmThread) == "dead" then StartBugFarm() end
    end
end

local function ForceStartBugFarm()
    if BugFarm.Enabled and not BugFarm.Running then StartBugFarm() end
end

--// API CREATION //--
local BugFarmAPI = {
    Start = StartBugFarm, Stop = StopBugFarm, Pause = PauseBugFarm, Resume = ResumeBugFarm, ForceStart = ForceStartBugFarm,
    SetConfig = function(newSettings)
        for key, value in pairs(newSettings) do if BugFarm[key] ~= nil then BugFarm[key] = value end end
    end,
    GetConfig = function() return BugFarm end,
    Blacklist = BugFarm.Blacklist, FieldsData = FieldsData, CalculateFields = CalculateFields, IsSpawnerReady = IsSpawnerReady,
}

print("[BugFarmCore] Модуль загружен. Возвращаем готовую таблицу API.")

-- Возвращаем полностью готовую таблицу API.
return BugFarmAPI
