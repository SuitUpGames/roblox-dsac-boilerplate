--[=[
@class PlayerService

Author: ArtemisTheDeer
Date: 11/15/2023
Project: roblox-dsac-boilerplate

Description: Basic boilerplate player service (Manages behavior w/players joining/leaving the game)
]=]

--GetService calls
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

--Module imports (Require)
local Knit: table = require(ReplicatedStorage.Packages.Knit)

local PlayerdataService: table
local PlayerService: table = Knit.CreateService({
    Name = "PlayerService"
})

local PACKAGES: Folder = ReplicatedStorage.Packages

--[=[
    Initialize PlayerService
    @param Player Player -- The player that joined the game
    @private
    @return nil
]=]
function PlayerService._playerAdded(Player: Player): nil
    print("Player added ", Player)
    local Playerdata = PlayerdataService:GetPlayerdata(Player)
    print(Playerdata:await())
end
--[=[
    Initialize PlayerService
    @return nil
]=]
function PlayerService:KnitInit(): nil
    PlayerdataService = Knit.GetService("PlayerdataService")
end

--[=[
    Start PlayerService
    @return nil
]=]
function PlayerService:KnitStart(): nil
    Players.PlayerAdded:Connect(self._playerAdded)

    for _,Player in Players:GetChildren() do
        self._playerAdded(Player)
    end
end


return PlayerService