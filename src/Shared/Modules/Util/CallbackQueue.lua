-- CallbackQueue
-- Author(s): Jesse Appleton
-- Date: 02/22/2022

--[[
    Creates a queue of callbacks that execute in the sequence they were added.
    Waits until the callback has completed or the timeout has been reached to move on to the next one.

    FUNCTION    CallbackQueue.new( processTimeout: number? = 60 ) -> {}
    FUNCTION    CallbackQueue:Add( fn: ()->(), ...: any ) -> ( Promise )
    FUNCTION    CallbackQueue:AddAsync( fn: ()->(), ...: any ) -> ( ...any )
]]

---------------------------------------------------------------------

-- Constants
local DEFAULT_TIMEOUT = 60 -- How long can a process in the queue take before it times out, by default?

-- Knit
local Knit = require( game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit") )
local Janitor = require( Knit.Packages.Janitor )
local Promise = require( Knit.Packages.Promise )
local t = require( Knit.Packages.t )

-- Modules

-- Roblox Services
local RunService = game:GetService("RunService")

-- Variables

---------------------------------------------------------------------


local CallbackQueue = {}
CallbackQueue.__index = CallbackQueue


local tNew = t.tuple( t.optional(t.numberPositive) )
function CallbackQueue.new( processTimeout: number? ): table
    assert( tNew(processTimeout) )

    processTimeout = processTimeout or DEFAULT_TIMEOUT

    local self = setmetatable( {}, CallbackQueue )
    self._janitor = Janitor.new()

    self._queue = {}
    self._processTimeout = processTimeout

    self._processNextEvent = Instance.new( "BindableEvent" )
    self._janitor:Add( self._processNextEvent )

    local function ProcessLoop(): ()
        local missedEvent: boolean = false
        local function ProcessEvent(): ()
            missedEvent = true
        end
        self._processNextEvent.Event:Connect( ProcessEvent )
        while ( not self._destroyed ) do
            if ( not missedEvent ) then
                self._processNextEvent.Event:Wait()
            end
            missedEvent = false
            task.spawn( self._processNext, self )
        end
    end
    task.spawn( ProcessLoop )

    return self
end


function CallbackQueue:_processNext(): ()
    if ( self.Processing ) then
        return
    end

    local nextCallback: ()->()? = self._queue[ 1 ]
    if ( nextCallback ) then
        self.Processing = true

        local continued: boolean?
        local function Continue(): ()
            if ( continued ) then return end
            continued = true

            table.remove( self._queue, 1 )
            self.Processing = false

            self._processNextEvent:Fire()
        end

        local complete: boolean?
        local function Process(): ()
            local result = {pcall(function()
                return nextCallback.Callback( table.unpack(nextCallback.Args) )
            end)}
            if ( not result[1] ) then
                warn( "CallbackQueue:", tostring(result[2]) )
            else
                table.remove( result, 1 )
                nextCallback.ResolvePromise( unpack(result) )
            end
            complete = true
            Continue()
        end
        task.spawn( Process )

        local nextStart = os.clock()
        repeat until ( complete ) or ( (os.clock()-nextStart) >= self._processTimeout ) or ( not task.wait() )
        Continue()
    end
end


local tAdd = t.tuple( t.callback )
function CallbackQueue:Add( callback: ()->(), ...: any ): ( Promise )
    assert( tAdd(callback) )
    assert( not self._destroyed, "Attempted to add to a destroyed CallbackQueue!" )

    -- This is super ugly, but I am unsure if there is a better way to do this?
    local resolvePromise: ()->()
    local finishPromise = Promise.new(function( resolve )
        resolvePromise = resolve
    end):catch( warn )

    table.insert( self._queue, {
        Callback = callback;
        Args = {...};
        ResolvePromise = resolvePromise;
    } )
    self._processNextEvent:Fire()

    return finishPromise
end


function CallbackQueue:AddAsync( callback: ()->(), ...: any ): ( ...any )
    local finishPromise: {} = self:Add( callback, ... )

    local result: {} = {
        finishPromise:await()
    }
    table.remove( result, 1 )

    return table.unpack( result )
end


function CallbackQueue:Destroy(): ()
    self._destroyed = true
    self._janitor:Destroy()
end


return CallbackQueue