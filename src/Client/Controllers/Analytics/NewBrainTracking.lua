--[=[
@class NewBrainTrackingController
@client

Author: James (stinkoDad20x6)
Date: 11/13/2023
Project: roblox-dsac-boilerplate
Description : track keepAlive with position and some player stats.
]=]

--GetService calls
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--Module imports (Require)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages.Promise)

local NewBrainTrackingController = Knit.CreateController({
	Name = "NewBrainTrackingController",
})

local LOCAL_PLAYER: Player = Players.LocalPlayer
local BASE_64_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#"

--[=[
    Generate a unique key based upon location
    @param Position vector3 -- The input position to convert to a Base64 string
    @return Promise<T> -- Returns a promise that resolves w/a Base64 string
]=]
function NewBrainTrackingController:_positionToBase64Key(Position: Vector3): table
	return Promise.new(function(Resolve, Reject)
		local PositionString = table.concat({
			string.format("%0.4i", (Position.X % 10000)),
			string.format("%0.4i", (Position.Y % 10000)),
			string.format("%0.4i", (Position.Z % 10000)),
		})

		local ResultString = ""

		while 1 * PositionString > 0 do
			local ModResult = PositionString % 64
			ResultString = string.sub(BASE_64_CHARS, ModResult + 1, ModResult + 1) .. ResultString
			PositionString = math.floor(PositionString / 64)
		end

		Resolve(ResultString)
	end)
end

--[=[
    Initialize NewBrainTrackingController
    @return nil
]=]
function NewBrainTrackingController:KnitInit(): nil end

--[=[
    Start NewBrainTrackingController
    @return nil
]=]
function NewBrainTrackingController:KnitStart(): nil end

return NewBrainTrackingController
