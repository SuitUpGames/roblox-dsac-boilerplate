--[=[
    @class Types
    This module exports a list of types that can be used for typechecking
]=]

--[=[
	@type ANY_TABLE {[any]: any}
	@within Types
	Generic table type (Wildcard) - accepts any values
]=]
export type ANY_TABLE = { [any]: any } -- A generic table type that accepts any values

--ReplicaService/ReplicaController/Replica (Class) related Types
--[=[
	@type ReplicaPathListener (newValue: any, oldValue: any) -> ()
	@within Types
]=]
export type ReplicaPathListener = (newValue: any, oldValue: any) -> ()
--[=[
	@type ReplicaListener (replica: Replica) -> ()
	@within Types
]=]
export type ReplicaListener = (replica: Replica) -> ()

--[=[
	@type ReplicaParams {ClassName: string, Data: { [string]: any }, Tags: { [string]: any }, Replication: (string | { Player })}
	@within Types
	Replica class parameters
]=]
export type ReplicaParams = {
	ClassName: string,
	Data: { [string]: any },
	Tags: { [string]: any },
	Replication: string | { Player },
	ReplicaId: string?,
}

--[=[
	@type ReplicaPath { string }
	@within Types
	A path to a key in the player's data (Eg. "_configuration._build")
]=]
export type ReplicaPath = { string }
--[=[
	@type Replica {
	ClassName: string,
	Data: { any },
	Tags: { any },
	Replication: { any },

	SetParent: (self: Replica, replica: Replica) -> (),
	DestroyFor: (self: Replica, Player) -> (),
	Destroy: (self: Replica) -> (),

	SetValue: (self: Replica, path: string, value: any) -> (),
	SetValues: (self: Replica, path: string, values: { [string]: any }) -> (),
	ArrayInsert: (self: Replica, path: string, value: any) -> (),
	ArraySet: (self: Replica, path: string, index: number, value: any) -> (),
	ArrayRemove: (self: Replica, path: string, index: number) -> (),

	ConnectOnServerEvent: (self: Replica, listener: () -> ()) -> (),
	ConnectOnClientEvent: (self: Replica, listener: () -> ()) -> (),

	ListenToChildAdded: (self: Replica, child: Replica) -> (),
	ListenToRaw: (self: Replica, listener: (listenerType: string, path: { string }, any) -> ()) -> (),
	ListenToChange: (self: Replica, path: string, listener: (newValue: any, oldValue: any) -> ()) -> (),
    ListenToNewKey: (self: Replica, path: string, listener: (value: any, newKey: string) -> ()) -> (),
	ListenToKeyChanged: (self: Replica, path: string, listener: (newValue: any, oldValue: any) -> ()) -> (), 
	ListenToArrayInsert: (self: Replica, path: string, listener: (index: number, value: any) -> ()) -> (),
	ListenToArraySet: (self: Replica, path: string, listener: (index: number, value: any) -> ()) -> (),
	ListenToArrayRemove: (self: Replica, path: string, listener: (index: number, value: any) -> ()) -> (),
}
	@within Types
	The members of the server/client Replica controller/service
]=]
export type Replica = {
	ReplicaId: string?,
	ClassName: string,
	Data: { any },
	Tags: { any },
	Replication: { any },

	SetParent: (self: Replica, replica: Replica) -> (),
	DestroyFor: (self: Replica, Player) -> (),
	Destroy: (self: Replica) -> (),

	SetValue: (self: Replica, path: string, value: any) -> (),
	SetValues: (self: Replica, path: string, values: { [string]: any }) -> (),
	ArrayInsert: (self: Replica, path: string, value: any) -> (),
	ArraySet: (self: Replica, path: string, index: number, value: any) -> (),
	ArrayRemove: (self: Replica, path: string, index: number) -> (),

	ConnectOnServerEvent: (self: Replica, listener: () -> ()) -> (),
	ConnectOnClientEvent: (self: Replica, listener: () -> ()) -> (),

	ListenToChildAdded: (self: Replica, child: Replica) -> (),
	ListenToRaw: (self: Replica, listener: (listenerType: string, path: { string }, any) -> ()) -> (),
	ListenToChange: (self: Replica, path: string, listener: (newValue: any, oldValue: any) -> ()) -> (),
	ListenToNewKey: (self: Replica, path: string, listener: (value: any, newKey: string) -> ()) -> (),
	ListenToKeyChanged: (self: Replica, path: string, listener: (newValue: any, oldValue: any) -> ()) -> (),
	ListenToArrayInsert: (self: Replica, path: string, listener: (index: number, value: any) -> ()) -> (),
	ListenToArraySet: (self: Replica, path: string, listener: (index: number, value: any) -> ()) -> (),
	ListenToArrayRemove: (self: Replica, path: string, listener: (index: number, value: any) -> ()) -> (),

	new: (ReplicaParams) -> Replica,
	andThen: (any) -> any,
	expect: (any) -> any,
}

return nil
