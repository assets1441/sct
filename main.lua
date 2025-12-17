print("loading......")
loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/BugFarmCore.lua'))()
repeat task.wait() until _G.BugFarmAPI
print("Bugs loaded!")
loadstring(game:HttpGet('https://raw.githubusercontent.com/assets1441/sct/refs/heads/main/Menu.lua'))()