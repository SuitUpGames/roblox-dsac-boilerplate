--[=[
@class ReplicaController
@client

Author: ArtemisTheDeer, loleris, luarook
Date: 11/16/2023
Project: roblox-dsac-boilerplate

Description: Custom replication controller for stateful values between client and server
Credit to loleris for using some of the code/ideas from ReplicaService for stateful replication, and luarook for their fork of ReplicaService (That was stripped down of unused functionality)
]=]

--GetService calls
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Types
local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)
type ANY_TABLE = Types.ANY_TABLE
type REPLICA = Types.Replica
type REPLICA_PARAMS = Types.ReplicaParams

--Module imports (Require)
local Knit: ANY_TABLE = require(ReplicatedStorage.Packages.Knit)
local ReplicaService: ANY_TABLE
local Promise: ANY_TABLE = require(ReplicatedStorage.Packages.Promise)
local Replica: REPLICA = require(script.Replica)
local Signal: ANY_TABLE = require(ReplicatedStorage.Packages.Signal)

local ReplicaController: ANY_TABLE = Knit.CreateController({
	Name = "ReplicaController",
	_replicas = {},
	replicaAdded = Signal.new(),
	replicaDestroyed = Signal.new(),
})

--[=[
    Creates a new replica
    @private
    @param params table -- [ReplicaParams] table
]=]
function ReplicaController:_createNewReplica(params: REPLICA_PARAMS)
	if not self._replicas[params.ReplicaId] then
		self._replicas[params.ReplicaId] = Replica.new(params)
	end

	self.replicaAdded:Fire(self._replicas[params.ReplicaId])
end

--[=[
    Destroys a replica and fires _replicaDestroyed with arguments (ClassName: string, replicaId: string)
    @private
    @param replicaId string -- The replica ID to destroy
]=]
function ReplicaController:_destroyReplica(replicaId: string)
	local replica: REPLICA | nil = self._replicas[replicaId]

	if replica then
		local replicaClass: string = replica.ClassName

		replica:Destroy()

		self._replicas[replicaId] = nil

		self._replicaDestroyed:Fire(replicaClass, replicaId)
	end
end

--[=[
    Updates the key(s)/value(s) within a specific [Replica] object
    @private
    @param replicaId string -- The [Replica] ID to update
    @param methodName string -- The method under the [Replica] object to call
    @param ... variadic -- Any arguments to pass along to the method under the [Replica] object
]=]
function ReplicaController:_updateReplica(replicaId: string, methodName: string, ...: any)
	local replica: REPLICA | nil
	local method: any
	local args: ANY_TABLE = {...} -- omghax, a way to get variadic args inside the promise

	--Wrap method in promise.defer (Resolves if method is successful, rejects if method does not exist/callback fails)
	return Promise.defer(function(Resolve, Reject)
		replica = self._replicas[replicaId]

		if not replica then
			return Reject(string.format("_updateReplica failed - replica ID %s not found!", replicaId))
		end

		method = replica[`_on{methodName}`]

		if not method then
			--return Reject(string.format("Method %s does not exist for replica!", methodName))
			return
		end

		method(replica, table.unpack(args))

		return Resolve()
	end):finally(function()
		method = nil
		--Cleanup references
		replica = nil
	end):catch(warn)
end

--[=[
    When a new [Replica] object of the 'class' parameter is added, the 'callback' function is called (The provided argument is the new [Replica] object)
    @param class string -- The class of replica that you want to connect to (Eg. "Playerdata")
    @param callback function -- A function that will be called when a new [Replica] object of the same class parameter is created - only argument provided is the newly created [Replica] object
    @return function -- Returns a function that (When called) disconnects the created script connection
]=]
function ReplicaController:replicaOfClassCreated(class: string, callback: any): any
	local connection: RBXScriptConnection

	connection = self.replicaAdded:Connect(function(newReplica: REPLICA)
		if newReplica.ClassName == class then
			Promise.defer(function(Resolve, Reject)
				callback(newReplica)
				Resolve()
			end)
		end
	end)

	return function()
		connection:Disconnect()
	end
end

--[=[
    
    @param class string -- The class of replica that you want to connect to (Eg. "Playerdata")
    @param callback function -- A function that will be called when a new [Replica] object of the same class parameter is created - only argument provided is the newly created [Replica] object
    @return function -- Returns a function that (When called) disconnects the created script connection
]=]

--[=[
    Initialize ReplicaController
]=]
function ReplicaController:KnitInit()
	ReplicaService = Knit.GetService("ReplicaService")

	ReplicaService.replicaAdded:Connect(function(replicaParams: REPLICA_PARAMS)
		self:_createNewReplica(replicaParams)
	end)

	ReplicaService.replicaDestroyed:Connect(function(replicaId: string)
		print("Destroying replica")
		self:_destroyReplica(replicaId)
	end)

	ReplicaService.replicaListener:Connect(function(replicaId: string, methodName: string, ...: any)
		self:_updateReplica(replicaId, methodName, ...)
	end)
end

--[=[
    Start ReplicaController
]=]
function ReplicaController:KnitStart() end

return ReplicaController
