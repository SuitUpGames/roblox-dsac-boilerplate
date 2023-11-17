local ReplicatedStorage = game:GetService("ReplicatedStorage")
--[[
    Author: @LuaRook
    Created: 8/11/2023
	Server-side replica module
]]

--[ Types ]--

local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)

export type Replica = Types.Replica
type ANY_TABLE = Types.ANY_TABLE
type ReplicaParams = Types.ReplicaParams
type ReplicaPathListener = Types.ReplicaPathListener
type ReplicaPath = Types.ReplicaPath

--[ Dependencies ]--

local Knit: ANY_TABLE = require(ReplicatedStorage.Packages.Knit)
local ReplicaService: ANY_TABLE
local Trove: ANY_TABLE = require(ReplicatedStorage.Packages.trove)
local Promise: ANY_TABLE = require(ReplicatedStorage.Packages.Promise)
local ReplicaUtil: ANY_TABLE = require(ReplicatedStorage.Shared.Modules.Util.ReplicaUtil)

--[ Roblox Services ]--

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

--[ Constants ]--

--[ Object References ]--

--[ Variables ]--

local DestroyedReplicas: { string } = {}

--[ Class ]--

local ServerReplica = {}
ServerReplica.__index = ServerReplica

function ServerReplica.new(params: ReplicaParams)
	if not ReplicaService then
		ReplicaService = Knit.GetService("ReplicaService")
	end

	return Promise.new(function(Resolve, Reject)
		print("New server replica")
		local newReplica = setmetatable({}, ServerReplica)
		newReplica._trove = Trove.new()

		-- Populate class with replica data from parameters
		if params and typeof(params) == "table" then
			-- Setup replica Id. This is monkeypatching, but this is also the
			-- easiest way to go about doing this.
			params.ReplicaId = HttpService:GenerateGUID(false)

			for key, value in pairs(params) do
				newReplica[key] = value
			end
		end

		newReplica._trove:Add(function()
			-- Destroy and disconnect all signals on replica destroyed
			ReplicaUtil.removeListeners(newReplica.ReplicaId)
			--TODO: Remove this replica from all other clients
		end)

		print("Finished making new replica")

		Resolve(newReplica)
		return
	end):catch(warn)
end

-- Returns JSON-encoded class
--@return string
function ServerReplica:Identify()
	return HttpService:JSONEncode(self)
end

--[=[
	Sets value from path.
	@param path string The path to update.
	@param value any The value to update the path to.
	@return Promise<T> -- Returns a promise that resolves if updated data should be sent to the client (An array of arguments to send via the [ReplicaService.newReplica] signal), and rejects if the key is the same/errors
]=]
function ServerReplica:SetValue(path: string, value: any): ANY_TABLE
	local parentPointer: any, lastKey: string | number | nil
	local oldValue: any

	return Promise.new(function(Resolve, Reject)
		-- Get data pointer
		parentPointer, lastKey = ReplicaUtil.getParent(path, self.Data)

		if not parentPointer and not lastKey then
			return Reject(string.format("SetValue failed - parentPointer and lastKey both missing.\nPath: %s", path))
		elseif parentPointer and not lastKey then
			return Reject(string.format("SetValue failed - lastKey missing.\nPath: %s", path))
		elseif not parentPointer and lastKey then
			return Reject(string.format("SetValue failed - parentPointer missing.\nPath: %s", path))
		end

		local stringKey: string = string.gsub(path, `.{lastKey}`, "")

		oldValue = parentPointer[lastKey]

		if oldValue == value then
			return Reject(
				string.format(
					"SetValue failed - old value is equal to new value and therefore does not need to be replicated.\nOld: %s\nNew: %s",
					tostring(oldValue),
					tostring(value)
				)
			)
		end

		local listenerActions: ANY_TABLE = {}

		--Update data
		--Add new listener actions to the table
		if not parentPointer[lastKey] then
			table.insert(listenerActions, { Action = "NewKey", Data = { stringKey, value, lastKey }, Path = path })
		end

		parentPointer[lastKey] = value

		table.insert(listenerActions, { Action = "Change", Data = { value, oldValue }, Path = path })

		return Resolve(listenerActions)
	end)
		:andThen(function(listenerActions: ANY_TABLE)
			for _, action: ANY_TABLE in listenerActions do
				self:_fireListener(action.Action, action.Path, table.unpack(action.Data))
			end
		end)
		:finally(function()
			-- Clear references
			parentPointer = nil
			lastKey = nil
			oldValue = nil
		end)
end

--[=[
	Sets multiple values at once from the path
	@param path string The path to update.
	@param values table A dictionary of values to update.
	@return Promise<T> -- Returns a promise that resolves if updated data should be sent to the client (An array of arguments to send via the [ReplicaService.replicaListener] signal), and rejects if the key is the same/errors
]=]
function ServerReplica:SetValues(path: string, values: { [string]: any }): ANY_TABLE
	local pointer: ANY_TABLE | nil

	return Promise.new(function(Resolve, Reject)
		-- Get data pointer
		pointer = ReplicaUtil.getPointer(path, self.Data)

		if not pointer then
			return Reject(string.format("SetValues failed - pointer not found. Path: %s", path))
		end

		local listenerActions: ANY_TABLE = {}

		for key: string, value: any in values do
			-- Fire new key signal
			local oldValue: any = pointer[key]

			if not oldValue then
				table.insert(listenerActions, { Action = "NewKey", Data = { path, value, key }, Path = path })
			end

			pointer[key] = value
			table.insert(listenerActions, { Action = "Change", Data = { value, oldValue }, Path = `{path}.{key}` })
		end

		return Resolve(listenerActions)
	end):finally(function()
		-- Clear references
		pointer = nil
	end)
end

--[=[
	Inserts value into array found at the specified path.
	@param path string The path of the array to update.
	@param value any The value to insert into the path array.
	@return Promise<T> -- Returns a promise that resolves with the data that should be replicated to the client + the length of the new array (An array of arguments to send via the [ReplicaService.replicaListener] signal), and rejects if the pointer does not exist
]=]
function ServerReplica:ArrayInsert(path: string, value: any): ANY_TABLE
	local pointer: ANY_TABLE | nil

	return Promise.new(function(Resolve, Reject)
		-- Get data pointer
		pointer = ReplicaUtil.getPointer(path, self.Data)

		if not pointer then
			return Reject(string.format("ArrayInsert failed - pointer not found. Path: %s", path))
		end

		-- Add entry to data
		table.insert(pointer, value)

		return Resolve({ "ArrayInsert", path, value }, #pointer)
	end):finally(function()
		-- Clear references
		pointer = nil
	end)
end

--[=[
	Sets index of array found at the specified path
	@param path string The path of the array to update
	@param index number The index to update in the specified table
	@param value any The value to set the index to
	@return Promise<T> -- Returns a promise that resolves with the data that should be replicated to the client + the index (An array of arguments to send via the [ReplicaService.replicaListener] signal), and rejects if the pointer does not exist, the index is not already set, or if the index value is equal to the new value
]=]
function ServerReplica:ArraySet(path: string, index: number, value: any): ANY_TABLE
	local pointer: ANY_TABLE | nil

	return Promise.new(function(Resolve, Reject)
		-- Get data pointer
		pointer = ReplicaUtil.getPointer(path, self.Data)

		if not pointer then
			return Reject(string.format("ArraySet failed - pointer not found. Path: %s", path))
		elseif not pointer[index] then
			return Reject(
				string.format(
					"ArraySet failed - index %s is not defined under pointer. Path: %s",
					tostring(index),
					path
				)
			)
		elseif pointer[index] == value then
			return Reject(
				string.format(
					"ArraySet failed - pointer index %s's value equals the new value. \nValue: %s\nPath: %s",
					tostring(index),
					tostring(value),
					path
				)
			)
		end

		-- Add entry to data
		pointer[index] = value

		return Resolve({ "ArraySet", path, index, value }, index)
	end):finally(function()
		-- Clear references
		pointer = nil
	end)
end

--[=[
	Removes index from array found at the specified path.
	@param path string The path of the array to update.
	@param index number The index to remove from the array.
	@return Promise<T> -- Returns a promise that resolves with the data that should be replicated to the client + the removed value (An array of arguments to send via the [ReplicaService.replicaListener] signal), and rejects if the pointer does not exist, the index is not already set, or if the index value is equal to the new value
]=]
function ServerReplica:ArrayRemove(path: string, index: number): ANY_TABLE
	local pointer: ANY_TABLE | nil

	return Promise.new(function(Resolve, Reject)
		-- Get data pointer
		pointer = ReplicaUtil.getPointer(path, self.Data)

		if not pointer then
			return Reject(string.format("ArrayRemove failed - pointer not found.\nPath: %s", path))
		end

		-- Remove entry from data
		local removedValue: any
		removedValue = table.remove(pointer, index)
		if removedValue == nil then
			return Reject(
				string.format(
					"ArrayRemove failed - no value was removed from the array.\nPath: %s\nIndex: %s",
					path,
					tostring(index)
				)
			)
		end

		return Resolve({ "ArrayRemove", path, index, removedValue }, removedValue)
	end):finally(function()
		pointer = nil
	end)
end

-- Listens to all changes
--@param listener function
function ServerReplica:ListenToRaw(listener: (listenerType: string, path: { string }, any) -> ()): RBXScriptConnection
	return self:_createListener("Raw", "Root", listener)
end

-- Listens to changes from `SetValue`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ServerReplica:ListenToChange(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("Change", path, listener)
end

-- Listens to new keys being added to the specified path.
--@param path string The path to listen for new keys in.
--@param listener ReplicaPathListener The function to call when a new key is added.
function ServerReplica:ListenToNewKey(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("NewKey", path, listener)
end

-- Listens to keys changed at the specified path.
--@param path string The path to listen to changes in.
--@param listener ReplicaPathListener The function to call when a key is changed.
function ServerReplica:ListenToKeyChanged(path: string, listener: ReplicaPathListener)
	return self:ListenToRaw(function(listenerType: string, changedPath: { string }, newValue: any, oldValue: any)
		if listenerType == "Change" and changedPath:sub(1, #path) == path then
			Promise.defer(function(Resolve, Reject)
				listener(newValue, oldValue)
				Resolve()
			end)
		end
	end)
end

-- Listens to changes from `ArrayInsert`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ServerReplica:ListenToArrayInsert(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("ArrayInsert", path, listener)
end

-- Listens to changes from `ArraySet`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ServerReplica:ListenToArraySet(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("ArraySet", path, listener)
end

-- Listens to changes from `ArrayRemove`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ServerReplica:ListenToArrayRemove(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("ArrayRemove", path, listener)
end

-- Adds task to replica cleanup.
--@param task any Task to add to replica cleanup.
function ServerReplica:AddCleanupTask(task: any): any
	return self._trove:Add(task)
end

-- Removes task from replica cleanup.
--@param task any The task to remove from replica cleanup.
function ServerReplica:RemoveCleanupTask(task: any): any
	self._trove:Remove(task)
	return
end

-- Wrapper for creating listeners.
--@param listenerType string The category for the listener.
--@param path string The path for the listener.
--@param listener function The listener to call when the path changes.
--@return RBXScriptConnection
function ServerReplica:_createListener(
	listenerType: string,
	path: string,
	listener: ReplicaPathListener
): RBXScriptConnection
	local connection = ReplicaUtil.createListener(self.ReplicaId, listenerType, path, listener)
	return self._trove:Add(connection)
end

--[=[
	Fires the listeners associated with this replica/path
	@param listenerType string -- The type of action to fire
	@param path string -- The path of the key (Eg. "_configuration._build")
	@param ... variadic -- Any additional arguments
	@private
	@server
]=]
function ServerReplica:_fireListener(listenerType: string, path: string, ...)
	--Fire the server-side listeners for this replica
	ReplicaUtil.fireListener(self.ReplicaId, listenerType, path, ...)
	ReplicaService:ReplicateChangesToClient(self.Replication, self.ReplicaId, listenerType, path, ...)
end

function ServerReplica:Destroy()
	self._trove:Destroy()
end

--[ Initialization ]--

--[ Return ]--

return ServerReplica
