--[=[
@class DataController
@client

Author: ArtemisTheDeer
Date: 11/14/2023
Project: roblox-dsac-boilerplate

Description: Player data Knit controller
]=]

--GetService calls
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--Module imports (Require)
local Knit: table = require(ReplicatedStorage.Packages.Knit)
local Promise: table = require(ReplicatedStorage.Packages.Promise)
local Signal: table = require(ReplicatedStorage.Packages.Signal)

local DataController: table = Knit.CreateController({
	Name = "DataController",
	_loadedPlayerdata = Signal.new(),
})

local LOCAL_PLAYER: Player = Players.LocalPlayer

--[=[
    @prop DATA_LOAD_TIMEOUT number
    @within DataController
    The max amount of time to wait for the playerdata to be cached on the client (From the server) on init before timing out and rejecting any associated promises/fallback behavior
]=]
local DATA_LOAD_TIMEOUT: number = 10

local Playerdata: table

--[=[
    Returns a promise that resolves with the playerdata once successfully loaded for the first time, and rejects if the player's data cannot be retrieved for some reason
    @client
    @yields
    @return Promise<T> -- Returns a promise that resolves with the playerdata/rejects if unable to get playerdata
]=]
function DataController:GetData(): table
	return Playerdata and Promise.resolve(Playerdata)
		or Promise.fromEvent(self._loadedPlayerdata):timeout(DATA_LOAD_TIMEOUT, "Timeout")
end

--[=[
    @client
    @param Key string -- The key that you want to lookup in the player data table
    @return Promise<T> -- Returns a promise that resolves w/the value from the player's data, and rejects if the player's data could not be loaded in time and/or the key does not exist
]=]
function DataController:GetKey(Key: string): table
	return Promise.new(function(Resolve, Reject)
		self:GetData()
			:andThen(function(Playerdata: table)
				if Playerdata[Key] then
					Resolve(Playerdata[Key])
				else
					Reject(string.format("Key '%s' does not exist in playerdata", Key))
				end
			end)
			:catch(Reject)
	end)
end

--[=[
    Initialize DataController
    @return nil
]=]
function DataController:KnitInit(): nil end

--[=[
    Start DataController
    @return nil
]=]
function DataController:KnitStart(): nil end

return DataController
