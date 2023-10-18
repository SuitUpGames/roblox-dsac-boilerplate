local startTime = os.clock()

local ServerStorage = game:GetService( "ServerStorage" )
local ReplicatedStorage = game:GetService( "ReplicatedStorage" )
--
local Knit = require( ReplicatedStorage.Packages.Knit )

-- EXPOSE ASSET FOLDERS
Knit.Assets = ReplicatedStorage.Assets

-- EXPOSE SERVER MODULES
Knit.Modules = ServerStorage.Modules

--EXPOSE SHARED MODULES
Knit.SharedModules = ReplicatedStorage.Shared.Modules
Knit.Helpers = Knit.SharedModules.Helpers
Knit.Enums = require( Knit.SharedModules.Enums )
Knit.GameData = Knit.SharedModules.Data
Knit.Packages = ReplicatedStorage.Packages

-- ENVIRONMENT SWITCHES
Knit.IsStudio = game:GetService( "RunService" ):IsStudio()
Knit.IsClient = game:GetService( "RunService" ):IsClient()
Knit.IsServer = game:GetService( "RunService" ):IsServer()

-- ADD SERVICES
local Services = ServerStorage.Services
Knit.AddServicesDeep( Services )

Knit:Start():andThen(function()
    print( string.format("Server Successfully Compiled! [%s ms]", math.round((os.clock()-startTime)*1000)) )
end):catch(error )