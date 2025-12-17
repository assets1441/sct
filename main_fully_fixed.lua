print("loading......")
loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/BugFarmCore.lua'))()
repeat task.wait() until _G.BugFarmAPI
print("Bugs loaded!")

-- Ensure the API restoration mechanism is always active
if not _G.APIRestorationActive then
    _G.APIRestorationActive = true
    
    -- Monitor API availability and restore if lost
    spawn(function()
        while true do
            task.wait(2) -- Check every 2 seconds for faster response
            
            -- Check if API exists
            if not _G.BugFarmAPI then
                print("Error: _G.BugFarmAPI not available! Reloading core...")
                
                -- Reload the core script to restore API
                local success, result = pcall(function()
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/BugFarmCore.lua'))()
                end)
                
                if success then
                    repeat task.wait() until _G.BugFarmAPI
                    print("BugFarmAPI restored successfully!")
                else
                    print("Failed to restore BugFarmAPI: " .. tostring(result))
                end
            end
        end
    end)
    
    -- Additional safety: monitor API function availability
    spawn(function()
        while true do
            task.wait(3) -- Check every 3 seconds
            
            if _G.BugFarmAPI then
                -- Test if key API functions exist
                local requiredFunctions = {"Start", "Stop", "Pause", "Resume", "ForceStart", "SetConfig", "GetConfig"}
                local apiValid = true
                
                for _, funcName in ipairs(requiredFunctions) do
                    if type(_G.BugFarmAPI[funcName]) ~= "function" then
                        apiValid = false
                        break
                    end
                end
                
                if not apiValid then
                    print("Warning: BugFarmAPI functions missing! Reloading core...")
                    
                    local success, result = pcall(function()
                        loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/BugFarmCore.lua'))()
                    end)
                    
                    if success then
                        repeat task.wait() until _G.BugFarmAPI
                        print("BugFarmAPI functions restored!")
                    else
                        print("Failed to restore BugFarmAPI functions: " .. tostring(result))
                    end
                end
            end
        end
    end)
end

loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/Menu.lua'))()