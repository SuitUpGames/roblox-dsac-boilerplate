--[=[
@class PlayerService

Author: ArtemisTheDeer
Date: 11/15/2023
Project: dasc-boilerplate

Description: Basic boilerplate player service (Manages behavior w/players joining/leaving the game)
]=]

--GetService calls
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)
type ANY_TABLE = Types.ANY_TABLE
--Module imports (Require)
local Knit: ANY_TABLE = require(ReplicatedStorage.Packages.Knit)

local PlayerdataService: ANY_TABLE
local PlayerService: ANY_TABLE = Knit.CreateService({
	Name = "PlayerService",
})

--[=[
    Function that is run when a player joins the game

    @param Player Player -- The player that joined the game
    @private
    @return nil
]=]
function PlayerService._playerAdded(Player: Player): nil
	PlayerdataService:GetPlayerdata(Player)
		:andThen(function(Data: ANY_TABLE)
			print("Playerdata successfully loaded ", Data)
		end)
		:catch(function(Message: any)
			warn("Could not load playerdata for player ", Player, ": ", Message)
		end)
	return nil
end

--[=[
    Function that is run when a player leaves the game
    @param Player Player -- The player that left the game
    @private
    @return nil
]=]
function PlayerService._playerRemoving(Player: Player): nil
	print("Player left the game ", Player)
	return nil
end

--[=[
    Initialize PlayerService
    @return nil
]=]
function PlayerService:KnitInit(): nil
	PlayerdataService = Knit.GetService("PlayerdataService")
	return nil
end

--[=[
    Start PlayerService
    @return nil
]=]
function PlayerService:KnitStart(): nil
	Players.PlayerAdded:Connect(self._playerAdded)
	Players.PlayerRemoving:Connect(self._playerRemoving)

	for _, Player in Players:GetChildren() do
		self._playerAdded(Player)
	end

	return nil
end

return PlayerService
