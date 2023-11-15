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

--Server knit functions/methods

--[=[
    Creates a new playerdata template via profileservice/replicaservice for a player
    @server
    @private
    @return Promise<T> -- A promise that resolves w/a copy of the player's data table if loaded successfully, and rejects if unable to load the player's data
]=]
function DataService:_createPlayerdataProfile(Player: Player): table
	return Promise.retry(
		Promise.new(function(Resolve, Reject)
			--A randomly generated GUID is used if the player is in studio & LOAD_PLAYERDATA_IN_STUDIO is set to false
			local useProductionKey: boolean = (not IS_STUDIO or LOAD_PLAYERDATA_IN_STUDIO)
			local dataKey: string = useProductionKey and DATA_PREFIX .. Player.UserId or HttpService:GenerateGUID()

			local playerProfile = self._profileStore:LoadProfileAsync(dataKey, "ForceLoad")

			if not playerProfile then
				return Reject(string.format("Could not load player profile %s", dataKey))
			end

			--Attach user ID to profile, reconcile data, and kick player/erase key from self._playerdata if they join another session
			playerProfile:AddUserId(Player.UserId)
			playerProfile:Reconcile()
			playerProfile:ListenToRelease(function()
				self._playerdata[Player] = nil
				Player:Kick("Your data was loaded on another server. Please rejoin in a few minutes.")
			end)

			Resolve(playerProfile)
		end),
		DATA_LOAD_RETRIES,
		DATA_LOAD_RETRY_DELAY
	):andThen(function(playerProfile: table)
		self._playerdata[Player] = {
			_profile = playerProfile,
		}

		self._playerdataLoaded:Fire(Player)
	end)
end

--[=[
    Returns a promise that resolves with a table of the player's data, and rejects if it cannot be retrieved for some reason
    If the playerdata is not loaded already, :_createPlayerdataProfile(Player: Player) will be called first
    @server
    @return Promise<T> -- A promise that resolves with a table of the player's data if the playerdata exists, and rejects if the playerdata does not exist
]=]
function DataService:GetPlayerdata(Player: Player): table
	return Promise.new(function(Resolve, Reject)
		if self._playerdata[Player] and self._playerdata[Player]._profile then
			return Resolve(self._playerdata[Player]._profile.Data)
		end

		if not self._playerdata[Player] then
			--If playerdata is not loaded, create new promise & set the _playerdata[Player] key to the new table once promise is resolved
			self._playerdata[Player] = {
				_profilePromise = self:_createPlayerdataProfile(Player)
					:andThen(function(playerProfile: table)
						Resolve(playerProfile.Data)
					end)
					:catch(Reject),
			}
		else
			--If playerdata is being loaded, wait for the _profilePromise to resolve/reject, and act accordingly
			self._playerdata[Player]._profilePromise
				:andThen(function(playerProfile: table)
					Resolve(playerProfile.Data)
				end)
				:catch(Reject)
		end
	end)
end

--Client knit functions/methods

--[=[
    Returns a promise that resolves with a table of the player's data, and rejects if it cannot be retrieved for some reason
    If the playerdata is not loaded already, :_createPlayerdataProfile(Player: Player) will be called server-side first
    @client
    @return Promise<T> -- A promise that resolves with a table of the player's data if the playerdata exists, and rejects if the playerdata does not exist
]=]
function DataService.Client:GetPlayerdata(Player: Player): table
	return self.Server:GetPlayerdata(Player)
end

--[=[
    Initialize DataService
    @server
    @return nil
]=]
function DataService:KnitInit(): nil
	local useProductionStore: boolean = (not IS_STUDIO or LOAD_PLAYERDATA_IN_STUDIO)
	--Use a temporary profilestore key if in studio & LOAD_PLAYERDATA_IN_STUDIO is set to false
	self._profileStore = ProfileService.GetProfileStore(useProductionStore and STORE_NAME or STORE_NAME .. os.time(), DATA_TEMPLATE)
end

--[=[
    Start DataService
    @server
    @return nil
]=]
function DataService:KnitStart(): nil end

return DataService
