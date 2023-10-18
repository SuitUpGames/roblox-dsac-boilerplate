-- InventoryHelper
-- Author(s): Salmon Jabed
-- Date: 08/08/2023

--[[ 
    SHARED
]]

local Packages: Folder = game.ReplicatedStorage.Packages
local Knit = require( Packages.Knit )
local t = require( Packages.t )

local PetData = require(Knit.GameData.PetData)

local AccessoryFolder = game.ReplicatedStorage.Assets.Accessories

local AvatarHelper = {}

local tAddAccessoryToCharacter = t.tuple(t.Model,t.table)
function AvatarHelper.AddAccessoryToCharacter(character: Model , accessory: table)
    assert(tAddAccessoryToCharacter(character,accessory))
    local humanoid = character.Humanoid
    local accessoryModel = AccessoryFolder:WaitForChild(accessory.Id):Clone()
    local accessoryTemplate = Instance.new("Accessory")
    local handle = accessoryModel:FindFirstChild("Handle")
    handle.Parent = accessoryTemplate
    accessoryTemplate.Name = accessory.Id
    accessoryTemplate:SetAttribute("Accessory",accessory.Type)
    accessoryModel:Destroy()
    humanoid:AddAccessory(accessoryTemplate)
end

local tRemoveAccessoryFromCharacter = t.tuple(t.Model,t.string)
function AvatarHelper.RemoveAccessoryFromCharacter(character , accessory: string)
    assert(tRemoveAccessoryFromCharacter(character,accessory))
    local accessoryToDestroy = character:FindFirstChild(accessory,true)
    if accessoryToDestroy then
        accessoryToDestroy:Destroy()
    end
end

return AvatarHelper