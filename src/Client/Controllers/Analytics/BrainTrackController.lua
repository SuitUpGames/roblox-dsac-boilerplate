--[[
BrainTrackController.lua
Author : James (steelheart2022)
Description : track keepAlive with position and some player stats.
]]

local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local LocalPlayer = Players.LocalPlayer

local BrainTrackController = Knit.CreateController({
	Name = "BrainTrackController",
})

function BrainTrackController:KnitInit()
	local BrainTrackService = Knit.GetService("BrainTrackService")
	task.spawn(function()
		while true do
			task.wait(50)
			BrainTrackService:track({ event = "keepAlive", choice = os.time() })
		end
	end)
end

return BrainTrackController
