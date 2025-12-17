print("loading......")
loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/BugFarmCore.lua'))()
repeat task.wait() until _G.BugFarmAPI
print("Bugs loaded!")

-- Add the backup API restoration mechanism directly in main script
spawn(function()
    while true do
        task.wait(5) -- Check every 5 seconds
        if not _G.BugFarmAPI then
            print("Error: _G.BugFarmAPI not available! Attempting to reload core...")
            loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/BugFarmCore.lua'))()
            repeat task.wait() until _G.BugFarmAPI
            print("BugFarmAPI restored!")
        end
        task.wait(1) -- Small delay to prevent spam
    end
end)

loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/Menu.lua'))()