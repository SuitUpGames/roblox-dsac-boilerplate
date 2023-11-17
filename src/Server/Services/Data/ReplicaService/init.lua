--[=[
@class ReplicaService

Author: ArtemisTheDeer
Date: 11/16/2023
Project: roblox-dsac-boilerplate

Description: Replica knit service
]=]

--GetService calls
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Types
local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)

type ANY_TABLE = Types.ANY_TABLE
type REPLICA = Types.Replica
type REPLICA_PARAMS = Types.ReplicaParams

--Module imports (Require)
local Knit: ANY_TABLE = require(ReplicatedStorage.Packages.Knit)
local Replica: REPLICA = require(script.Replica)

local ReplicaService: ANY_TABLE = Knit.CreateService({
	Name = "ReplicaService",
	_replicas = {},
	Client = {
		replicaAdded = Knit.CreateSignal(),
		replicaDestroyed = Knit.CreateSignal(),
		replicaListener = Knit.CreateSignal(),
	},
})



--[=[
    Create a new [Replica] object
    @param ClassName string -- The ClassName of the [Replica] object
    @param Replication {Player} | Player -- An array of (Or single) player(s) to replicate this data to
    @param Tags {string} -- An optional array of strings to assign to this object (For keeping track of inheritance)
    @param Body {any} -- A key/pair table of values to replicate to the client (Accepts strings as keys, and key/pair values/arrays - do not mix key/pair + arrays together!)
    @return Promise<T> -- Returns a promise that resolves with [Replica], replicaId: string if a replica is successfully created, and rejects if it is not
]=]
function ReplicaService:CreateReplica(
	ClassName: string,
	Replication: { Player } | string,
	Tags: ANY_TABLE | nil,
	Body: ANY_TABLE
): REPLICA
	local replicaParams: REPLICA_PARAMS = {
		Replication = Replication,
		Data = Body,
		Tags = Tags,
		ClassName = ClassName,
	}

	return Replica.new(replicaParams):andThen(function(newReplica: ANY_TABLE)
		if not newReplica then
			warn("No new replica")
		else
			local replicateAll: boolean = not Replication or Replication == "All"

			for _, Player: Player in replicateAll and Players:GetChildren() or Replication do
				self.Client.replicaAdded:Fire(Player, replicaParams)
			end

			self._replicas[newReplica.ReplicaId] = newReplica
		end

		return newReplica
	end)
end

function ReplicaService:ReplicateChangesToClient(Replication: {Player}, replicaId: string, listenerType: string, path: string, ...: any)
	for _,Player in Replication do
		self.Client.replicaListener:Fire(Player, replicaId, listenerType, path, ...)
	end
end

--[=[
    Initialize ReplicaService
]=]
function ReplicaService:KnitInit() end

--[=[
    Start ReplicaService
]=]
function ReplicaService:KnitStart() end

return ReplicaService
