--[[
BrainTrackController.lua
Author : James (stinkoDad20x6)
Description : track keepAlive with position and some player stats.
]]

local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local LocalPlayer = Players.LocalPlayer
local DataController


local BrainTrackController = Knit.CreateController({
    Name = "BrainTrackController",
})

function BrainTrackController:KnitInit()
    local BrainTrackService = Knit.GetService("BrainTrackService")
    DataController = Knit.GetController("DataController")
    spawn(function()
        while true do
            wait(50)
            local PlayerName = game.Players.LocalPlayer.Name
            local Position = game.Players:waitForChild(PlayerName).Character.HumanoidRootPart.Position
            local choice = "NoData"
            if (DataController and DataController:GetReplica()) then
                --todo prioritize data and shorten
                choice = DataController:GetReplica().Data
            end
            BrainTrackService:track( {event = 'keepAlive',
              choice=choice,
              subchoice= math.floor(Position.X * 10) ..','.. math.floor(Position.Y * 10) ..','.. math.floor(Position.Z * 10)
            })
        end
    end)

    spawn(function()
        local HttpService = game:GetService("HttpService")
        local teleportData = game:GetService("ReplicatedFirst"):WaitForChild('TeleportDetect'):WaitForChild('teleportData',10)
        if (nil ~= teleportData) then
            BrainTrackService:track({
                event = "LPArrivedTeleport",
                choice = HttpService:JSONEncode(teleportData or "no data"),
                scene = "fromBT",
            })
        end
    end)
end

return BrainTrackController