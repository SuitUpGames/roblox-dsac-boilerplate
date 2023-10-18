-- DataController
-- Author(s): Jesse
-- Date: 12/06/2021

--[[
    FUNCTION    DataController:GetDataByName( name: string ) -> ( any? )
    FUNCTION    DataController:GetDataChangedSignal( name: string, createIfNoExists: boolean ) -> ( Signal? )
    FUNCTION    DataController:ObserveDataChanged( name: string, callback: ()->() ) -> ( Connection )
]]

---------------------------------------------------------------------


-- Constants

-- Knit
local Packages = game:GetService("ReplicatedStorage").Packages
local Knit = require( Packages:WaitForChild("Knit") )
local Signal = require( Packages.Signal )
local Promise = require( Packages.Promise )
local t = require( Packages.t )
local DataService

-- Roblox Services

-- Variables

---------------------------------------------------------------------

local DataController = Knit.CreateController {
    Name = "DataController";
    Data = {};
    ChangedSignals = {};
    Initialized = false;
    InitializationComplete = Signal.new();
}

function DataController:WaitForInitialization(): ()
    return self.Initialized or self.InitializationComplete:Wait()
end

function DataController:GetData()
    repeat task.wait() until self.Initialized
    return self.Data
end

local tGetDataByName = t.tuple( t.string )
function DataController:GetDataByName( name: string ): ( any? )
    assert( tGetDataByName(name) )
    self:WaitForInitialization()
    return self.Data[ name ]
end


local tGetDataChangedSignal = t.tuple( t.string, t.optional(t.boolean) )
function DataController:GetDataChangedSignal( name: string, createIfNoExists: boolean? ): ( table )
    assert( tGetDataChangedSignal(name, createIfNoExists) )
    if ( not createIfNoExists ) then
        self:WaitForInitialization()
    end

    local findSignal = self.ChangedSignals[ name ]
    if ( findSignal ) then
        return findSignal
    elseif ( createIfNoExists ) then 
        local newSignal = Signal.new()
        self.ChangedSignals[ name ] = newSignal
        return newSignal
    else
        return error( "No data changed signal found for \"" .. tostring(name) .. "\"!" )
    end
end


local tObserveDataChanged = t.tuple( t.string, t.callback )
function DataController:ObserveDataChanged( name: string, callback: ()->() ): ()
    assert( tObserveDataChanged(name, callback) )
    local dataChangedSignal = self:GetDataChangedSignal( name )
    local function Update( ... )
        callback( ... )
    end
    Update( self:GetDataByName(name) )
    return dataChangedSignal:Connect( Update )
end


function DataController:_recieveDataUpdate( name: string, value: any? ): ( any? )
    local changedSignal = self:GetDataChangedSignal( name, true )
    --print( "Recieved data update for", name, "| Value:", value )
    self.Data[ name ] = value
    changedSignal:Fire( value )
end


function DataController:_recieveTableIndexUpdate( name: string, index: string, value: any? ): ()
    local changedSignal = self:GetDataChangedSignal( name, true )
    local findTable: {} = self:GetDataByName( name )
    if ( typeof(findTable) == "table" ) then
        findTable[ index ] = value
        changedSignal:Fire( findTable )
    end
end


function DataController:KnitStart(): ()
    local dataPromise = Promise.new(function( resolve, reject )
        local function GetData()
            return pcall(function()
                return DataService:GetPlayerData()
            end)
        end

        local success, data
        repeat
            success, data = GetData()
        until ( success and data ) or ( not task.wait(1) )

        resolve( data )
    end):andThen(function( data )
        for name, value in pairs( data ) do
            task.spawn( self._recieveDataUpdate, self, name, value )
        end

        self.Initialized = true
        self.InitializationComplete:Fire()
    end):catch(warn )
end


function DataController:KnitInit(): ()
    DataService = Knit.GetService( "DataService" )

    DataService.ReplicateData:Connect(function( ... )
        self:_recieveDataUpdate( ... )
    end)

    DataService.ReplicateTableIndex:Connect(function( ... )
        self:_recieveTableIndexUpdate( ... )
    end)
end


return DataController