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
    @yields
    @return Promise<T>
]=]
function DataController:WaitForInitialization(): table
    return Playerdata and Promise.resolve(Playerdata) or Promise.fromEvent(self._loadedPlayerdata):timeout()
end

--[=[
    Initialize DataController
    @return nil
]=]
function DataController:KnitInit(): nil

end

--[=[
    Start DataController
    @return nil
]=]
function DataController:KnitStart(): nil
    
end


return DataController