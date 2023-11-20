--[=[
@class DataController
@client

Author: ArtemisTheDeer
Date: 11/14/2023
Project: Sparkles

Description: Player data Knit controller
]=]

--GetService calls
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Types
local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)
type ANY_TABLE = Types.ANY_TABLE
type REPLICA = Types.Replica

--Module imports (Require)
local Knit: ANY_TABLE = require(ReplicatedStorage.Packages.Knit)
local Promise: ANY_TABLE = require(ReplicatedStorage.Packages.Promise)
local Signal: ANY_TABLE = require(ReplicatedStorage.Packages.Signal)
local ReplicaController: ANY_TABLE

local DataController: ANY_TABLE = Knit.CreateController({
	Name = "DataController",
	_loadedPlayerdata = Signal.new(),
	_dataUpdatedSignals = {},
})

--[=[
    @prop DATA_LOAD_TIMEOUT number
    @within DataController
    The max amount of time to wait for the playerdata to be cached on the client (From the server) on init before timing out and rejecting any associated promises/fallback behavior
]=]
local DATA_LOAD_TIMEOUT: number = 10

local cachedPlayerdata: ANY_TABLE

--[=[
    Returns a promise that resolves with the playerdata once successfully loaded for the first time, and rejects if the player's data cannot be retrieved for some reason
    @client
    @yields
    @return Promise<T> -- Returns a promise that resolves with the playerdata/rejects if unable to get playerdata
]=]
function DataController:GetData(): ANY_TABLE
	return cachedPlayerdata and Promise.resolve(cachedPlayerdata.Data)
		or Promise.fromEvent(self._loadedPlayerdata):timeout(DATA_LOAD_TIMEOUT, "Timeout")
end

--[=[
    Returns a promise that resolves with a specific value (Looked up by key) from the playerdata, and rejects if the playerdata was unable to be loaded/the key does not exist
    @client
    @param Key string -- The key that you want to lookup in the player data table
    @return Promise<T> -- Returns a promise that resolves w/the value from the player's data, and rejects if the player's data could not be loaded in time and/or the key does not exist
]=]
function DataController:GetKey(Key: string): ANY_TABLE
	return Promise.new(function(Resolve, Reject)
		self:GetData()
			:andThen(function(Playerdata: ANY_TABLE)
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
    Returns a signal that fires (With the value) when the Key argument in the playerdata is updated
    @client
    @yields
    @param Key string -- The key that you want to lookup in the player data table. Can be a specific path if desired (Eg. "Currencies" to listen to currency changes as a whole or "Currencies.Coins" to listen to all coin changes)
    @return Promise<T> -- Returns a promise that resolves w/a signal that fires when the specific key is updated, and rejects if the playerdata isn't loaded in-time
]=]
function DataController:GetKeyUpdatedSignal(Key: string): ANY_TABLE
	return Promise.new(function(Resolve, Reject)
		self:GetData()
			:andThen(function()
				--TODO: I believe this can be replaced w/the signals used by ReplicaUtil
				if self._dataUpdatedSignals[Key] then
					return Resolve(self._dataUpdatedSignals[Key]._signal)
				end

				self._dataUpdatedSignals[Key] = { _signal = Signal.new(), _replicaConnection = nil }

				self._dataUpdatedSignals[Key]._replicaConnection = cachedPlayerdata:ListenToKeyChanged(
					Key,
					function(newData: any, oldData: any)
						self._dataUpdatedSignals[Key]._signal:Fire(newData)
					end
				)

				return Resolve(self._dataUpdatedSignals[Key]._signal)
			end)
			:catch(Reject)
	end)
end

--[=[
    Removes a data updated connection from the table
    Warning: Will disconnect all events tied to that key!
    @client
    @param Key string -- The key to disconnect - can be a specific path if desired (Eg. "Currencies" to disconnect a signal for "Currencies" or "Currencies.Coins" to disconnect the "Coins" signal)
    @return nil
]=]
function DataController:DisconnectKeyUpdatedSignal(Key: string): nil
	if self._dataUpdatedSignals[Key] then
		self._dataUpdatedSignals[Key]._signal:Destroy()
		self._dataUpdatedSignals[Key]._replicaConnection:Destroy()
	end

	return
end

--[=[
    Initialize DataController
	Get the replica of the playerdata from the server, and then set the cachedPlayerdata varaible as the replica
    @return nil
]=]
function DataController:KnitInit(): nil
	ReplicaController = Knit.GetController("ReplicaController")

	ReplicaController:replicaOfClassCreated("Playerdata", function(playerdataReplica: REPLICA)
		cachedPlayerdata = playerdataReplica
		self._loadedPlayerdata:Fire(playerdataReplica.Data)
	end)

	return
end

--[=[
    Start DataController
    @return nil
]=]
function DataController:KnitStart(): nil
	return
end

return DataController
