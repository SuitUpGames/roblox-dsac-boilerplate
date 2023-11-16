local ReplicatedStorage = game:GetService("ReplicatedStorage")
--[=[
	@class DataTemplate

	DataTemplate is the table template for what new player/existing player save data should look like (structure-wise)
	Keys must be strings
	Values can be strings, numbers, or a table
]=]

local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)
type ANY_TABLE = Types.ANY_TABLE

local BUILD_VERSION: number = game.PlaceVersion

--[=[
	@interface KEYS_TO_IGNORE
	@within DataTemplate

	An array of strings to ignore w/replication to clients
]=]
local KEYS_TO_IGNORE: ANY_TABLE = {
	_build=true,
}

--[=[
	@interface Playerdata
	@within DataTemplate

	._build string -- The version of the game that this player's data was last saved with

	The default playerdata template for new players
]=]
local Playerdata = {
	_configuration={
		_build=BUILD_VERSION
	}
}

return {Playerdata=Playerdata,KEYS_TO_IGNORE=KEYS_TO_IGNORE}