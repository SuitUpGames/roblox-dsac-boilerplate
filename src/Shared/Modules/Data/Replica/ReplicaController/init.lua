--[=[
@class initController
@client

Author: LuaRook/loleris
Forked by ArtemisTheDeer and ported to knit controller/service
Date: 11/16/2023
Project: roblox-dsac-boilerplate

Description: ReplicaService knit controller
]=]

--GetService calls
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--Types
local Types = require(ReplicatedStorage.Shared.Modules.Data.Types)

type ANY_TABLE = Types.ANY_TABLE

--Module imports (Require)
local Knit: ANY_TABLE = require(ReplicatedStorage.Packages.Knit)
local Replica: ANY_TABLE = require(script.Replica)

local initController: ANY_TABLE = Knit.CreateController({
    Name = "initController"
})

local LOCAL_PLAYER: Player = Players.LocalPlayer

--[=[
    Initialize initController
]=]
function initController:KnitInit()
    
end

--[=[
    Start initController
]=]
function initController:KnitStart()
    
end


return initController