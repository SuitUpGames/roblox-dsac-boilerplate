-- InventoryHelper
-- Author(s): Jesse Appleton
-- Date: 03/29/2023

--[[
    SERVER-ONLY
        FUNCTION    InventoryHelper.AddToInventory( inventory: { InventoryEntry }, entry: InventoryEntry ) -> ( boolean, {[string]: any} )
        FUNCTION    InventoryHelper.AddBatchToInventory( inventory: { InventoryEntry }, batchData: { {InventoryEntry} } ) -> ( boolean )
        FUNCTION    InventoryHelper.RemoveFromInventoryByName( inventory: { InventoryEntry }, name: string, count: number? = 1 ) -> ( boolean, {string} )
        FUNCTION    InventoryHelper.RemoveBatchFromInventoryByGUID( inventory: { InventoryEntry }, guids: {string} ) -> ( boolean, {string} )

    SHARED
        FUNCTION    InventoryHelper.GetUniqueInventoryEntryNames( inventory: { InventoryEntry } ) -> ( {} )
        FUNCTION    InventoryHelper.CountInventoryEntries( inventory: { InventoryEntry } ) -> ( number )
        FUNCTION    InventoryHelper.CountInventoryEntriesByName( inventory: { InventoryEntry }, name: string ) -> ( number )
        FUNCTION    InventoryHelper.GetInventoryEntriesByName( inventory: { InventoryEntry }, name: string, count: number? = 1 ) -> ( { InventoryEntry } )
        FUNCTION    InventoryHelper.GetInventoryEntryByName( inventory: { InventoryEntry }, name: string ) -> ( InventoryEntry? )
        FUNCTION    InventoryHelper.GetInventoryEntryByGUID( inventory: { InventoryEntry }, guid: string ) -> ( InventoryEntry? )
        FUNCTION    InventoryHelper.GetInventoryEntriesByNameIgnoreGUID( inventory: { InventoryEntry }, ignoreGUID: string, name: string, count: number? = 1 ) -> ( { InventoryEntry } )
        FUNCTION    InventoryHelper.GetInventoryEntriesWithFilter( inventory: { InventoryEntry }, filter: {[string]: any}, count: number) -> ( { InventoryEntry} )
        FUNCTION    InventoryHelper.CountInventoryEntriesWithFilter( inventory: { InventoryEntry }, filter: {[string]: any}, count: number) -> (number)
]]


---------------------------------------------------------------------


-- Types
type InventoryEntry = {
    GUID: string,
    Name: string,
    [string]: any
}


-- Constants
local IS_SERVER = game:GetService( "RunService" ):IsServer()

-- Knit
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Knit = require( Packages:WaitForChild("Knit") )
local t = require( Packages.t )
local CallbackQueue = require( Packages.CallbackQueue )

-- Roblox Services
local HttpService = game:GetService( "HttpService" )

-- Variables
local EditQueue = CallbackQueue.new( 1 )

---------------------------------------------------------------------

local function SingleThreadedCallback( callback ): ( (...any)->(...any) )
    return function( ... )
        return EditQueue:AddAsync( callback, ... )
    end
end

local function ServerOnly()
    return IS_SERVER, "Attempted to use a server-only method!"
end


local function IsValidInventory()
    return t.values( t.keys(t.string) )
end


local InventoryHelper = {}


local tGetUniqueEntryNames = t.tuple( IsValidInventory )
function InventoryHelper.GetUniqueInventoryEntryNames( inventory: {InventoryEntry} ): ( {string} )
    assert( tGetUniqueEntryNames(inventory) )

    local uniqueNames: {string} = {}
    for _, data: InventoryEntry in pairs( inventory ) do
        if ( not table.find(uniqueNames, data.Name) ) then
            table.insert( uniqueNames, data.Name )
        end
    end

    return uniqueNames
end


local tCountInventoryEntries = t.tuple( IsValidInventory )
function InventoryHelper.CountInventoryEntries( inventory: {InventoryEntry} ): ( number )
    assert( tCountInventoryEntries(inventory) )

    local count: number = 0
    for _ in pairs( inventory ) do
        count += 1
    end

    return count
end


local tCountInventoryEntriesByName = t.tuple( IsValidInventory, t.string )
function InventoryHelper.CountInventoryEntriesByName( inventory: {InventoryEntry}, name: string ): ( number )
    assert( tCountInventoryEntriesByName(inventory, name) )

    local count: number = 0
    for _, data: InventoryEntry in pairs( inventory ) do
        if ( data.Name == name ) then
            count += 1
        end
    end

    return count
end

function InventoryHelper.CountInventoryEntriesWithFilter( inventory: {InventoryEntry}, filter: {}, count: number? )
    local entriesCount: number = 0
    
    if( not count ) then
        -- Don't take count into consideration
        count = math.huge
    end
    for _, data in pairs( inventory ) do
        local isValidFilter: boolean = true 
        for filterName, filterValue in pairs( filter ) do 
            if data[ filterName ] ~= filterValue then 
                isValidFilter = false
            end
        end
        if isValidFilter then 
            entriesCount += 1

            if( entriesCount == count ) then
                break
            end
        end
    end
    return entriesCount
end


local tGetInventoryEntriesByFilter = t.tuple( IsValidInventory, t.keys(t.string))
function InventoryHelper.GetInventoryEntriesWithFilter( inventory: {InventoryEntry}, filter: {}, count: number? ): ({ InventoryEntry}?, number )
    assert( tGetInventoryEntriesByFilter(inventory, filter) )
    local filteredInventory = {}
    local entriesCount: number = 0

    if not count then 
        -- Don't take count into consideration
        count = math.huge
    end
    for _, data: InventoryEntry in pairs( inventory ) do 
        local isValidFilter: boolean = true
        for name: string, value: string | number in pairs(filter) do 
            if data[name] ~= value then 
                isValidFilter = false
                break
            end
        end
        if isValidFilter then 
            filteredInventory[ data.GUID ] = data
            entriesCount += 1

            if( entriesCount == count ) then
                break
            end
        end
    end
    return filteredInventory, entriesCount
end

local tGetInventoryEntryByGUID = t.tuple( IsValidInventory, t.string )
function InventoryHelper.GetInventoryEntryByGUID( inventory: {InventoryEntry}, guid: string ): ( InventoryEntry? )
    assert( tGetInventoryEntryByGUID(inventory, guid) )
    return inventory[guid]
end


local tGetInventoryEntryByGUID = t.tuple( IsValidInventory, t.string )
function InventoryHelper.GetInventoryEntryByName( inventory: {InventoryEntry}, name: string ): ( InventoryEntry? )
    assert( tGetInventoryEntryByGUID(inventory, name) )

    for _, data: InventoryEntry in pairs( inventory ) do
        if ( data.Name == name ) then
            return data
        end
    end

    return nil
end

local tGetInventoyEntryByFilter = t.tuple( IsValidInventory, t.string)
function InventoryHelper.GetInventoryEntryWithFilter(inventory, filter): ( InventoryEntry? )
    assert( tGetInventoyEntryByFilter(inventory, filter) ) 
    local filteredInventory = {}
    for _, data: InventoryEntry in pairs( inventory ) do 
        local isInFilter: boolean = true
        for filterName, filterValue in pairs(filter) do 
            if not data[filterName] == filterValue then
                isInFilter = false
                continue
            end
        end
        if isInFilter then 
            table.insert(filteredInventory, data)
        end
    end

    return filteredInventory
end


local tGetInventoryEntriesByName = t.tuple( IsValidInventory, t.string, t.string, t.optional(t.every(t.integer, t.numberPositive)) )
function InventoryHelper.GetInventoryEntriesByNameIgnoreGUID( inventory: {InventoryEntry}, ignoreGUID: string, name: string, count: number? ): ( {InventoryEntry} )
    assert( tGetInventoryEntriesByName(inventory, ignoreGUID, name, count) )

    count = count or 1

    local sortedEntries: {InventoryEntry} = {}
    for _, data: InventoryEntry in pairs( inventory ) do
        if ( data.Name == name ) and ( data.GUID ~= ignoreGUID ) then
            table.insert( sortedEntries, data )
        end
    end

    table.sort(sortedEntries, function(a, b)
        return ( a.Level or 0 ) < ( b.Level or 0 )
    end)

    local foundEntries: {InventoryEntry} = {}
    for i = 1, math.min(count, #sortedEntries) do
        table.insert( foundEntries, sortedEntries[i] )
    end

    return foundEntries
end


local tGetInventoryEntriesByName = t.tuple( IsValidInventory, t.string, t.optional(t.every(t.integer, t.numberPositive)) )
function InventoryHelper.GetInventoryEntriesByName( inventory: {InventoryEntry}, name: string, count: number? ): ( {InventoryEntry} )
    assert( tGetInventoryEntriesByName(inventory, name, count) )

    count = count or math.huge

    local sortedEntries: {InventoryEntry} = {}
    for _, data: InventoryEntry in pairs( inventory ) do
        if ( data.Name == name ) then
            table.insert( sortedEntries, data )
        end
    end

    table.sort(sortedEntries, function(a, b)
        return ( a.Level or 0 ) < ( b.Level or 0 )
    end)

    local foundEntries: {InventoryEntry} = {}
    for i = 1, math.min(count, #sortedEntries) do
        table.insert( foundEntries, sortedEntries[i] )
    end

    return foundEntries
end


local tAddToInventory = t.tuple( IsValidInventory, t.keys(t.string) )
function InventoryHelper.AddToInventory( inventory: {InventoryEntry}, data: InventoryEntry ): ( boolean, InventoryEntry )
    assert( ServerOnly() )
    assert( tAddToInventory(inventory, data) )

    if ( not data.GUID ) then
        data.GUID = HttpService:GenerateGUID( false )
    end

    inventory[ data.GUID ] = data

    return true, data
end
InventoryHelper.AddToInventory = SingleThreadedCallback( InventoryHelper.AddToInventory )


local tAddBatchToInventory = t.tuple( IsValidInventory, t.values(t.table) )
function InventoryHelper.AddBatchToInventory( inventory: {InventoryEntry}, dataBatch: {InventoryEntry} ): ( boolean )
    assert( ServerOnly() )
    assert( tAddBatchToInventory(inventory, dataBatch) )

    for _, data: InventoryEntry in pairs( dataBatch ) do
        if ( not data.GUID ) then
            data.GUID = HttpService:GenerateGUID( false )
        end
        inventory[ data.GUID ] = data
    end

    return true
end
InventoryHelper.AddBatchToInventory = SingleThreadedCallback( InventoryHelper.AddBatchToInventory )


local tRemoveFromInventoryByName = t.tuple( IsValidInventory, t.string, t.optional(t.every(t.numberPositive, t.integer)) )
function InventoryHelper.RemoveFromInventoryByName( inventory: {InventoryEntry}, name: string, count: number? ): ( boolean, {string} )
    assert( ServerOnly() )
    assert( tRemoveFromInventoryByName(inventory, name, count) )

    count = count or 1

    local entriesRemoved: {} = {}
    for index: string, data: InventoryEntry in pairs( inventory ) do
        if ( data.Name == name ) then
            table.insert( entriesRemoved, index )
            inventory[ index ] = nil

            count -= 1
            if ( count <= 0 ) then
                break
            end
        end
    end

    return ( #entriesRemoved > 0 ), entriesRemoved
end
InventoryHelper.RemoveFromInventoryByName = SingleThreadedCallback( InventoryHelper.RemoveFromInventoryByName )


local tRemoveFromInventoryByGUID = t.tuple( IsValidInventory, t.string )
function InventoryHelper.RemoveFromInventoryByGUID( inventory: {InventoryEntry}, guid: string ): ( boolean )
    assert( ServerOnly() )
    assert( tRemoveFromInventoryByGUID(inventory, guid) )

    local itemRemoved: boolean = false
    for index: string, data: InventoryEntry in pairs( inventory ) do
        if ( data.GUID == guid ) then
            itemRemoved = true
            inventory[ index ] = nil
            break
        end
    end

    return itemRemoved
end
InventoryHelper.RemoveFromInventoryByGUID = SingleThreadedCallback( InventoryHelper.RemoveFromInventoryByGUID )


local tRemoveBatchFromInventoryByGUID = t.tuple( IsValidInventory, t.values(t.string) )
function InventoryHelper.RemoveBatchFromInventoryByGUID( inventory: {InventoryEntry}, guids: {string} ): ( boolean, {string} )
    assert( ServerOnly() )
    assert( tRemoveBatchFromInventoryByGUID(inventory, guids) )

    local entriesRemoved: {string} = {}
    for _, guid: string in pairs( guids ) do
        for index: string, data: InventoryEntry in pairs( inventory ) do
            if ( data.GUID == guid ) then
                table.insert( entriesRemoved, index )
                inventory[ index ] = nil
                break
            end
        end
    end

    return ( #entriesRemoved > 0 ), entriesRemoved
end
InventoryHelper.RemoveBatchFromInventoryByGUID = SingleThreadedCallback( InventoryHelper.RemoveBatchFromInventoryByGUID )

local tRemoveFromInventoryByFilter = t.tuple( IsValidInventory, t.keys(t.string), t.optional(t.number) )
function InventoryHelper.RemoveFromInventoryByFilter( inventory: {InventoryEntry}, filter: string, max_count: number ): (boolean, {string} )
    assert( ServerOnly() )
    assert( tRemoveFromInventoryByFilter(inventory, filter, max_count))

    if not max_count then 
        max_count = 100
    end

    local entriesRemoved: {string} = {}
    local count: number = 0
    for index, data in pairs( inventory ) do
        local isValidFilter: boolean = true
        for name, value in pairs( filter ) do 
            if data[ name ] ~= value then 
                isValidFilter = false
            end
        end
        if isValidFilter and count < max_count then 
            table.insert(entriesRemoved, index)
            inventory[index] = nil
            count += 1
        end
    end
    return ( #entriesRemoved > 0 ), entriesRemoved
end
InventoryHelper.RemoveFromInventoryByFilter = SingleThreadedCallback( InventoryHelper.RemoveFromInventoryByFilter )

return InventoryHelper