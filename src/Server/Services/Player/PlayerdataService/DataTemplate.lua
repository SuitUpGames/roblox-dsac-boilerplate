--[=[
	@class DataTemplate

	DataTemplate is the table template for what new player/existing player save data should look like (structure-wise)
]=]

local BUILD_VERSION: number = game.PlaceVersion

--[=[
	@interface Playerdata
	@within DataTemplate

	._build string -- The version of the game that this player's data was last saved with
]=]
local Playerdata = {
	_build = BUILD_VERSION,
}

return Playerdata