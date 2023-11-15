--[=[
@class DataService

Author: serverOptimist & ArtemisTheDeer
Date: 11/15/2023
Project: roblox-dsac-boilerplate

Description: Rewrite of serverOptimist DataService module
]=]

--GetService calls
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

--Module imports (Require)
local Knit: table = require(ReplicatedStorage.Packages.Knit)
local Signal: table = require(ReplicatedStorage.Packages.Signal)
local Promise: table = require(ReplicatedStorage.Packages.Promise)
local ProfileService: table = require(script.ProfileService)

local DataService: table = Knit.CreateService({
	Name = "DataService",
	Client = {},
	_playerdata = {},
	_playerdataLoaded = Signal.new("PlayerdataLoaded"),
})

local PACKAGES: Folder = ReplicatedStorage.Packages

local DATA_TEMPLATE: table = require(script.DataTemplate)

local IS_STUDIO: boolean = RunService:IsStudio()

--[=[
    @prop STORE_NAME string
    @within DataService
    The datastore to use with profileservice for storing playerdata
]=]
local STORE_NAME: string = "Playerdata"

--[=[
    @prop DATA_PREFIX string
    @within DataService
    The prefix to amend to the key used for saving playerdata (Eg. "Playerdata_123")
]=]
local DATA_PREFIX: string = "playerdata_"
--[=[
    @prop DATA_LOAD_TIMEOUT number
    @within DataService
    The max amount of time to wait for the playerdata to be loaded before rejecting an associated promise
]=]
local DATA_LOAD_TIMEOUT: number = 30

--[=[
    @prop DATA_LOAD_RETRIES number
    @within DataService
    The maximum amount of times to try to load a player's data (On joining the game) before rejecting the promise associated w/it
]=]
local DATA_LOAD_RETRIES: number = 10

--[=[
    @prop DATA_LOAD_RETRY_DELAY number
    @within DataService
    How long to wait between failed attempts with loading a player's data (On joining the game) before retrying
]=]
local DATA_LOAD_RETRY_DELAY: number = 10

--[=[
    @prop LOAD_PLAYERDATA_IN_STUDIO boolean
    @within DataService
    Boolean that determines whether player save profiles should be loaded while in a Roblox studio session
    If true, playerdata will load in studio. If false, playerdata will not be loaded in studio
]=]
local LOAD_PLAYERDATA_IN_STUDIO: boolean = true

--[=[
    Creates a new playerdata template via profileservice/replicaservice for a player
    @server
    @private
    @return Promise<T> -- A promise that resolves w/a copy of the player's data table if loaded successfully, and rejects if unable to load the player's data
]=]
function DataService:_createPlayerdataProfile(Player: Player): table
	return Promise.retry(Promise.new(function(Resolve, Reject)
        --A randomly generated GUID is used if the player is in studio & LOAD_PLAYERDATA_IN_STUDIO is set to false
        local useProductionKey: boolean = (not IS_STUDIO or LOAD_PLAYERDATA_IN_STUDIO)
        local dataKey: string = useProductionKey and DATA_PREFIX..Player.UserId or HttpService:GenerateGUID()

        local playerProfile = 
    end), DATA_LOAD_RETRIES, DATA_LOAD_RETRY_DELAY)
end

--[=[
    Gets a copy of the playerdata (Table)
    @server
    @return Promise<T> -- A promise that resolves if the playerdata exists, and rejects if the playerdata does not exist
]=]
function DataService:GetPlayerdata(Player: Player): table
	return Promise.new(function(Resolve, Reject)
		if self._playerdata[Player] then
			return Resolve(self._playerdata[Player]._profile.Data)
		end

		Promise.fromEvent(self._playerdataLoaded, function(loadedPlayer: Player)
			return Player == loadedPlayer
		end)
			:timeout(DATA_LOAD_TIMEOUT, "Timeout")
			:catch(Reject)
	end)
end

--[=[
    Initialize DataService
    @return nil
]=]
function DataService:KnitInit(): nil
    local useProductionStore: boolean = (not IS_STUDIO or LOAD_PLAYERDATA_IN_STUDIO)
    --Use a temporary profilestore key if in studio & LOAD_PLAYERDATA_IN_STUDIO is set to false
    self._profileStore = ProfileService.GetProfileStore(useProductionStore and STORE_NAME or STORE_NAME..os.time(), DATA_TEMPLATE)
end

--[=[
    Start DataService
    @return nil
]=]
function DataService:KnitStart(): nil
end

return DataService
