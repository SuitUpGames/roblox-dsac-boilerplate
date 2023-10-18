if not game:IsLoaded() then
	game.Loaded:Wait()
end

local startTime = os.clock()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.LocalPlayer = game:GetService("Players").LocalPlayer
Knit.PlayerGui = Knit.LocalPlayer:WaitForChild("PlayerGui")

-- EXPOSE ASSETS FOLDERS
Knit.Assets = ReplicatedStorage.Assets

-- EXPOSE CLIENT MODULES
Knit.Modules = script.Parent:WaitForChild("Modules")

--EXPOSE SHARED MODULES
Knit.SharedModules = game.ReplicatedStorage.Shared.Modules
Knit.Helpers = Knit.SharedModules.Helpers

Knit.Enums = require(Knit.SharedModules.Enums)
Knit.GameData = Knit.SharedModules.Data
Knit.Packages = ReplicatedStorage.Packages

-- ENVIRONMENT SWITCHES
Knit.IsStudio = game:GetService("RunService"):IsStudio()
Knit.IsClient = game:GetService("RunService"):IsClient()
Knit.IsServer = game:GetService("RunService"):IsServer()

-- DISABLE HURT FLASH IN COREGUI
local StarterGui = game:GetService("StarterGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ADD CONTROLLERS
local Controllers = script.Parent.Controllers
require(script.Parent.Interface)
Knit.AddControllersDeep(Controllers)

-- ADD COMPONENTS
local Components = script.Parent.Components
for _, v in Components:GetDescendants() do
	if v:IsA("ModuleScript") then
		require(v)
	end
end

-- START
Knit:Start()
	:andThen(function()
		print(string.format("Client Successfully Compiled! [%s ms]", math.round((os.clock() - startTime) / 1000)))
	end)
	:catch(error)
