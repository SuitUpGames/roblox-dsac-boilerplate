--!strict

--[=[
@class PlayerdataService

Author: serverOptimist & ArtemisTheDeer
Date: 11/15/2023
Project: roblox-dsac-boilerplate

Description: Rewrite of serverOptimist PlayerdataService module
]=]

--Lua types
type ANY_TABLE = { [any]: any} -- A generic table type that accepts any values

--GetService calls
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--Module imports (Require)
local PACKAGES: any = ReplicatedStorage.Packages
local Knit: ANY_TABLE = require(PACKAGES.Knit)
local Signal: ANY_TABLE = require(PACKAGES.Signal)
local Promise: ANY_TABLE = require(PACKAGES.Promise)
local ProfileService: ANY_TABLE = require(script.ProfileService)
local Replica: ANY_TABLE = require(PACKAGES.Replica)

local PlayerdataService: ANY_TABLE = Knit.CreateService({
	Name = "PlayerdataService",
	Client = {},
	_playerdata = {},
	_playerdataLoaded = Signal.new(),
	_playerdataUnloaded = Signal.new(),
})

local DATA_TEMPLATE: ANY_TABLE = require(script.DataTemplate)

local IS_STUDIO: boolean = RunService:IsStudio()

--[=[
    @prop STORE_NAME string
    @within PlayerdataService
    The datastore to use with profileservice for storing playerdata
]=]
local STORE_NAME: string = "Playerdata"

--[=[
    @prop DATA_PREFIX string
    @within PlayerdataService
    The prefix to amend to the key used for saving playerdata (Eg. "Playerdata_123")
]=]
local DATA_PREFIX: string = "playerdata_"

--[=[
    @prop DATA_LOAD_RETRIES number
    @within PlayerdataService
    The maximum amount of times to try to load a player's data (On joining the game) before rejecting the promise associated w/it
]=]
local DATA_LOAD_RETRIES: number = 10

--[=[
    @prop DATA_LOAD_RETRY_DELAY number
    @within PlayerdataService
    How long to wait between failed attempts with loading a player's data (On joining the game) before retrying
]=]
local DATA_LOAD_RETRY_DELAY: number = 10

--[=[
    @prop LOAD_PLAYERDATA_IN_STUDIO boolean
    @within PlayerdataService
    Boolean that determines whether player save profiles should be loaded while in a Roblox studio session
    If true, playerdata will load in studio. If false, playerdata will not be loaded in studio
]=]
local LOAD_PLAYERDATA_IN_STUDIO: boolean = false
local USE_PRODUCTION_STORE: boolean = (not IS_STUDIO or LOAD_PLAYERDATA_IN_STUDIO)

--Client knit functions/methods

--[=[
    Returns a promise that resolves with a table of the player's data, and rejects if it cannot be retrieved for some reason
    If the playerdata is not loaded already, :_createPlayerdataProfile(Player: Player) will be called server-side first
    @client
    @return Promise<T> -- A promise that resolves with a table of the player's data if the playerdata exists, and rejects if the playerdata does not exist
]=]
function PlayerdataService.Client:GetPlayerdata(Player: Player): ANY_TABLE
	return self.Server:GetPlayerdata(Player)
end

--Server knit functions/methods

--[=[
    Creates a new playerdata template via profileservice/replicaservice for a player
    @server
    @private
    @return Promise<T> -- A promise that resolves w/a copy of the player's data table if loaded successfully, and rejects if unable to load the player's data
]=]
function PlayerdataService:_createPlayerdataProfile(Player: Player): ANY_TABLE
	return Promise.new(function(Resolve, Reject)
		Promise.retryWithDelay(function()
			return Promise.new(function(resolveData, rejectData)
				local dataKey: string = DATA_PREFIX .. Player.UserId

				--Use the mock API under the profilestore
				local playerProfile: ANY_TABLE | nil = USE_PRODUCTION_STORE
						and self._profileStore:LoadProfileAsync(dataKey, "ForceLoad")
					or self._profileStore.Mock:LoadProfileAsync(dataKey, "ForceLoad")

				if not playerProfile then
					return rejectData(string.format("Could not load player profile %s", dataKey))
				end

				--Attach user ID to profile, reconcile data, and kick player/erase key from self._playerdata if they join another session
				playerProfile:AddUserId(Player.UserId)
				playerProfile:Reconcile()
				playerProfile:ListenToRelease(function()
					if not self._playerdata[Player] then
						return
					end

					self._playerdata[Player] = nil

					self._playerdataUnloaded:Fire(Player)

					Player:Kick("Your data was loaded on another server. Please rejoin in a few minutes.")
				end)

				--Cleanup player data when player is leaving the game
				Player.AncestryChanged:Connect(function(_: any, newParent: any)
					if not newParent then
						if self._playerdata[Player] and self._playerdata[Player]._profile then
							self._playerdata[Player]._profile:Release()
						end

						self._playerdata[Player] = nil
						self._playerdataUnloaded:Fire(Player)
					end
				end)

				self._playerdata[Player] = {
					_profile = playerProfile,
				}

				resolveData(playerProfile)
			end)
		end, DATA_LOAD_RETRIES, DATA_LOAD_RETRY_DELAY)
			:andThen(function()
				Resolve(self._playerdata[Player]._profile.Data)
			end)
			:catch(Reject)
	end):andThen(function()
		self._playerdataLoaded:Fire(Player)
	end)
end

--[=[
    Returns a promise that resolves with a table of the player's data, and rejects if it cannot be retrieved for some reason
    If the playerdata is not loaded already, :_createPlayerdataProfile(Player: Player) will be called first
    @server
    @return Promise<T> -- A promise that resolves with a table of the player's data if the playerdata exists, and rejects if the playerdata does not exist
]=]
function PlayerdataService:GetPlayerdata(Player: Player): ANY_TABLE
	return Promise.new(function(Resolve, Reject)
		if self._playerdata[Player] and self._playerdata[Player]._profile then
			return Resolve(self._playerdata[Player]._profile.Data)
		end

		if not self._playerdata[Player] then
			--If playerdata is not loaded, create new promise & set the _playerdata[Player] key to the new table once promise is resolved
			self._playerdata[Player] = {
				_profilePromise = self:_createPlayerdataProfile(Player)
					:andThen(function()
						Resolve(self._playerdata[Player]._profile.Data)
					end)
					:catch(Reject),
			}
		else
			--If playerdata is being loaded, wait for the _profilePromise to resolve/reject, and act accordingly
			self._playerdata[Player]._profilePromise
				:andThen(function()
					Resolve(self._playerdata[Player]._profile.Data)
				end)
				:catch(Reject)
		end
	end)
end

--[=[
    Initialize PlayerdataService
    @server
    @return nil
]=]
function PlayerdataService:KnitInit()
	self._profileStore = ProfileService.GetProfileStore(STORE_NAME, DATA_TEMPLATE)
end

--[=[
    Start PlayerdataService
    @server
    @return nil
]=]
function PlayerdataService:KnitStart() end

return PlayerdataService
