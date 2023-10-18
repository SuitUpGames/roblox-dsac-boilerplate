-- DataService
-- Author(s): serverOptimist
-- Date: 03/28/2022

--[[
    
]]

---------------------------------------------------------------------

-- Constants
-- local STORE_NAME = ( game:GetService("RunService"):IsStudio() and ("Data_" .. os.time()) ) or "DevelopmentData3"
local STORE_NAME = "Data_" .. os.time()
local DATA_KEY = "Player_%s2"

-- Knit
local Packages = game.ReplicatedStorage.Packages
local Knit = require( Packages:WaitForChild("Knit") )
local Signal = require(Packages.Signal)
local Promise = require( Packages.Promise )
local t = require( Packages.t )
local Timer = require( Packages.Timer )

-- Modules

-- Roblox Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Variables
local DataTemplate = require(script.DataTemplate)
local ProfileService = require( script.ProfileService )
local ProfileStore = ProfileService.GetProfileStore( STORE_NAME, DataTemplate )
-- Objects

---------------------------------------------------------------------


local DataService = Knit.CreateService {
    Name = "DataService";
    Client = {
        ReplicateData = Knit.CreateSignal();
        ReplicateTableIndex = Knit.CreateSignal();
    };
    PlayerData = {};
    PlayerDataLoaded = Signal.new();
}

local signals: table = {}

local function GetPlayerSignal( player, signalName ): ( {} )
    local playerSignals = if signals[player] then signals[player] else {}
    signals[player] = playerSignals
    local signal = if playerSignals[signalName] then playerSignals[signalName] else Signal.new()
    playerSignals[signalName] = signal
    return signal
end

function DataService.Client:GetPlayerData( player: Player ): ( {}? )
    local profile: {}? = self.Server:GetPlayerDataAsync( player )
    return profile and profile.Data
end


local tReplicatePlayerData = t.tuple( t.instanceIsA("Player"), t.string, t.optional(t.any) )
function DataService:ReplicatePlayerData( player: Player, name: string, data: any? ): ()
    assert( tReplicatePlayerData(player, name, data) )

    self.Client.ReplicateData:Fire( player, name, data )
end


-- Use this method to only replicate an index within a table
-- Example: If I had a table called "Trails" and I just changed some data in Trails.Example I would just do
-- DataService:ReplicateTableIndex( player, "Trails", "Example" )
local tReplicateTableIndex = t.tuple( t.instanceIsA("Player"), t.string, t.any )
function DataService:ReplicateTableIndex( player: Player, name: string, index: string ): ()
    assert( tReplicateTableIndex(player, name, index) )
    local profile: {} = self:GetPlayerDataAsync( player )
    if ( not profile ) then return end

    local targetTable: {} = profile.Data[ name ]
    assert( typeof(targetTable) == "table", string.format("ReplicateTableIndex expects second parameter \"name\" to reference a table in player's data, \"%s\" got %s", name, typeof(targetTable)) )

    GetPlayerSignal( player, name ):Fire( profile.Data[name], player )

    self.Client.ReplicateTableIndex:Fire( player, name, index, targetTable[index] )
end


local tGetPlayerDataAsync = t.tuple( t.instanceIsA("Player") )
function DataService:GetPlayerDataAsync( player: Player ): ( {}? )
    assert( tGetPlayerDataAsync(player) )
    local data
    repeat
        data = self.PlayerData[ player ]
    until ( data ) or ( not player:IsDescendantOf(game) ) or ( not task.wait() )
    return data
end


local tGetDataChangedSignal = t.tuple( t.string, t.instanceIsA("Player") )
function DataService:GetDataChangedSignal( signalName: string, player: Player ): ( {} )
    assert( tGetDataChangedSignal(signalName, player) )
    return GetPlayerSignal( player, signalName )
end


local tGetPlayerDataPromise = t.tuple( t.instanceIsA("Player") )
function DataService:GetPlayerDataPromise( player: Player ): ( {} )
    assert( tGetPlayerDataPromise(player) )

    return Promise.new(function( resolve, reject )
        local data = self:GetPlayerDataAsync( player )
        if ( data ) then
            resolve( data )
        else
            reject( "Couldn't get Player's data!" )
        end
    end)
end

local tSetPlayerData = t.tuple( t.instanceIsA("Player"), t.string, t.optional(t.any), t.optional(t.boolean) )
function DataService:SetPlayerData( player: Player, dataName: string, value: any?, replicateToClient: boolean? ): ()
    assert( tSetPlayerData(player, dataName, value, replicateToClient) )

    replicateToClient = if replicateToClient ~= nil then replicateToClient else true

    local profile: {} = self:GetPlayerDataAsync( player )
    if ( not profile ) then return end

    local oldValue: any? = profile.Data[ dataName ]
    profile.Data[ dataName ] = value
    GetPlayerSignal( player, dataName ):Fire( value, player )

    if ( replicateToClient ) then
        self:ReplicatePlayerData( player, dataName, value )
    end
end


local tIncrementPlayerData = t.tuple( t.instanceIsA("Player"), t.string, t.number, t.optional(t.boolean) )
function DataService:IncrementPlayerData( player: Player, dataName: string, incrementAmount: number, replicateToClient: boolean? ): ()
    assert( tIncrementPlayerData(player, dataName, incrementAmount, replicateToClient) )

    replicateToClient = if replicateToClient ~= nil then replicateToClient else true

    local profile: {} = self:GetPlayerDataAsync( player )
    if ( not profile ) then return end

    local oldValue: number = profile.Data[ dataName ]
    assert( type(oldValue) == "number", string.format("Tried to increment \"%s\" which is a %s", oldValue, type(oldValue)) )
    local newValue: number = profile.Data[ dataName ] + incrementAmount
    profile.Data[ dataName ] = newValue

    GetPlayerSignal( player, dataName ):Fire( newValue, player )

    if ( replicateToClient ) then
        self:ReplicatePlayerData( player, dataName, newValue )
    end
end

function DataService:KnitStart(): ()

    local function OnPlayerAdded( player: Player): ()
        local dataKey = ( RunService:IsStudio() and HttpService:GenerateGUID(false) ) or string.format(DATA_KEY, player.UserId)
        local profile = ProfileStore:LoadProfileAsync( dataKey, "ForceLoad" )
        if ( profile ) then
            profile:AddUserId( player.UserId )
            profile:Reconcile()
            profile:ListenToRelease(function()
                self.PlayerData[ player ] = nil
                player:Kick( "Your data was loaded on another server. Please rejoin in a few minutes." )
            end)

            if ( player:IsDescendantOf(game) ) then
                self.PlayerData[ player ] = profile
                self.PlayerDataLoaded:Fire( player, profile )
            else
                profile:Release()
            end
        else
            player:Kick( "We were unable to load your data. Please rejoin in a few minutes.")
        end
    end
    for index: number, player: Player in next, game.Players:GetPlayers() do 
        task.spawn(OnPlayerAdded, player)
    end
    game.Players.PlayerAdded:Connect( OnPlayerAdded )

    local function ClearPlayerSignals( player: Player ): ()
        local playerSignals: {}? = signals[ player ]
        if ( playerSignals ) then
            for _, signal in pairs( playerSignals ) do
                signal:Destroy()
            end
        end
        signals[ player ] = nil
    end

    local function OnPlayerRemoving( player: Player ): ()
        local profile = self.PlayerData[ player ]
        if ( profile ) then
            self.PlayerData[ player ] = nil
            profile:Release()
        end

        task.spawn( ClearPlayerSignals, player )
    end
    game.Players.PlayerRemoving:Connect( OnPlayerRemoving )
    -- This is purely a lightweight safety catch for edge-case memory leaks
    local function SweepOldSignals(): ()
        for player in pairs( signals ) do
            if ( not player:IsDescendantOf(game.Players) ) then
                OnPlayerRemoving( player )
            end
        end
    end
    Timer.Simple( 300, SweepOldSignals )
end


function DataService:KnitInit(): ()
    
end


return DataService