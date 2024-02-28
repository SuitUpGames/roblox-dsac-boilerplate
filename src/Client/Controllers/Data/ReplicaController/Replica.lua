--[=[
	@class Replica
	Replica class (Client)
]=]

--[[
    Author: @LuaRook
	Forked by: ArtemisTheDeer 11/16/23
    Created: 8/11/2023
]]

--[ Roblox Services ]--

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[ Types ]--
local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)
type ANY_TABLE = Types.ANY_TABLE
export type Replica = Types.Replica
type ReplicaParams = Types.ReplicaParams
type ReplicaListener = Types.ReplicaListener
type ReplicaPathListener = Types.ReplicaPathListener

--[ Dependencies ]--

local Promise: ANY_TABLE = require(ReplicatedStorage.Packages.Promise)
local ReplicaUtil: ANY_TABLE = require(ReplicatedStorage.Shared.Modules.Util.ReplicaUtil)
local Trove: ANY_TABLE = require(ReplicatedStorage.Packages.trove)

--[ Root ]--

local ClientReplica = {}
ClientReplica.__index = ClientReplica

--[ Variables ]--

--[ API ]--

function ClientReplica.new(params)
	local self = setmetatable({}, ClientReplica)
	self._trove = Trove.new()
	self.ClassName = params.ClassName
	self.ReplicaId = params.ReplicaId
	self.Data = params.Data
	self.Tags = params.Tags

	-- Handle cleanup
	self._trove:Add(function()
		-- Destroy and disconnect all signals on replica destroyed
		ReplicaUtil.removeListeners(self.ReplicaId)
	end)

	-- Fire creation signal
	return self
end

-- Returns JSON-encoded class
--@return string
function ClientReplica:Identify()
	return HttpService:JSONEncode(self)
end

-- Listens to all changes
--@param listener function
function ClientReplica:ListenToRaw(listener: (listenerType: string, path: { string }, any) -> ()): RBXScriptConnection
	return self:_createListener("Raw", "Root", listener)
end

-- Listens to changes from `SetValue`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ClientReplica:ListenToChange(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("Change", path, listener)
end

-- Listens to new keys being added to the specified path.
--@param path string The path to listen for new keys in.
--@param listener ReplicaPathListener The function to call when a new key is added.
function ClientReplica:ListenToNewKey(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("NewKey", path, listener)
end

-- Listens to keys changed at the specified path.
--@param path string The path to listen to changes in.
--@param listener ReplicaPathListener The function to call when a key is changed.
function ClientReplica:ListenToKeyChanged(path: string, listener: ReplicaPathListener)
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
function ClientReplica:ListenToArrayInsert(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("ArrayInsert", path, listener)
end

-- Listens to changes from `ArraySet`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ClientReplica:ListenToArraySet(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("ArraySet", path, listener)
end

-- Listens to changes from `ArrayRemove`.
--@param path string The path to listen to changes to.
--@param listener ReplicaPathListener The function to call when the path is updated.
function ClientReplica:ListenToArrayRemove(path: string, listener: ReplicaPathListener): RBXScriptConnection
	return self:_createListener("ArrayRemove", path, listener)
end

-- Adds task to replica cleanup.
--@param task any Task to add to replica cleanup.
function ClientReplica:AddCleanupTask(task: any): any
	return self._trove:Add(task)
end

-- Removes task from replica cleanup.
--@param task any The task to remove from replica cleanup.
function ClientReplica:RemoveCleanupTask(task: any): any
	self._trove:Remove(task)
	return nil
end

-- Wrapper for creating listeners.
--@param listenerType string The category for the listener.
--@param path string The path for the listener.
--@param listener function The listener to call when the path changes.
--@return RBXScriptConnection
function ClientReplica:_createListener(listenerType: string, path: string, listener: ReplicaPathListener): RBXScriptConnection
	local connection = ReplicaUtil.createListener(self.ReplicaId, listenerType, path, listener)
	return self._trove:Add(connection)
end

function ClientReplica:_fireListener(listenerType: string, path: string, ...)
	ReplicaUtil.fireListener(self.ReplicaId, listenerType, path, ...)
end

--[ Listener Handlers ]--

function ClientReplica._onChange(self: ANY_TABLE, path: string, value: any)
	-- Get data pointer
	local parentPointer, lastKey = ReplicaUtil.getParent(path, self.Data)
	local oldValue: any = parentPointer[lastKey]

	-- Update data
	if parentPointer and lastKey then
		parentPointer[lastKey] = value
		self:_fireListener("Change", path, value, oldValue)
	end

	-- Remove references
	oldValue = nil
	parentPointer = nil
	lastKey = nil
end

function ClientReplica._onNewKey(self: ANY_TABLE, path: string, value: any, key: string)
	-- Fire listener for new key added
	self:_fireListener("NewKey", path, value, key)
end

function ClientReplica._onArrayInsert(self: ANY_TABLE, path: string, value: any): number
	-- Get data pointer
	local pointer = ReplicaUtil.getPointer(path, self.Data)

	-- Add entry to data
	if pointer then
		table.insert(pointer, value)
		self:_fireListener("ArrayInsert", path, #pointer, value)
	end

	return #pointer
end

function ClientReplica._onArraySet(self: ANY_TABLE, path: string, index: number, value: any): number
	-- Get data pointer
	local pointer = ReplicaUtil.getPointer(path, self.Data)

	-- Add entry to data
	if pointer and pointer[index] ~= nil then
		pointer[index] = value
		self:_fireListener("ArraySet", path, index, value)
	end

	-- Remove reference
	pointer = nil
end

function ClientReplica._onArrayRemove(self: ANY_TABLE, path: string, index: number): any
	-- Get data pointer
	local pointer = ReplicaUtil.getPointer(path, self.Data)

	-- Remove entry from data
	if pointer then
		local removedValue: any = table.remove(pointer, index)
		self:_fireListener("ArrayRemove", path, index, removedValue)
	end

	-- Remove references
	pointer = nil
	return
end

function ClientReplica:Destroy()
	self._trove:Destroy()
end

--[ Initialization ]--

--[ Return ]--

return ClientReplica
