-- InventoryHelper
-- Author(s): Jesse Appleton
-- Date: 08/08/2023

--[[ 
    SHARED
        FUNCTION    PetHelper.GetPetByName( petName: string ): table
        FUNCTION    PetHelper.MakeAccessoryOnPet( petModel: Model, accessoryTable: table )
        FUNCTION    PetHelper.GetPetsWithFilter( filter: table ): table
        FUNCTION    PetHelper.GetRandomPetByRarity( rarity: string ): table
        FUNCTION    PetHelper.GetNextRarityByName( rarity: string ): string
        FUNCTION    PetHelper.GetWeightByRarity( rarity: string ): number
        FUNCTION    PetHelper.GetRarityByWeight( weight: number ): string
        FUNCTION    PetHelper.GetNextShineByName( shine: string ): string
]]

local Packages: Folder = game.ReplicatedStorage.Packages
local Knit = require( Packages.Knit )
local t = require( Packages.t )

local PetData = require(Knit.GameData.PetData)

local AccessoryFolder = game.ReplicatedStorage.Assets.Accessories

local PetMaximumLevel = 50

local Randomize = Random.new()

local PetHelper = {}

local tGetPetByName = t.tuple(t.string)
function PetHelper.GetPetByName( petName: string ): table
    assert( tGetPetByName(petName) )
    for _, pet in pairs( PetData.Pets ) do 
        if( pet.Name == petName ) then 
            return pet
        end
    end
end

local tAddAccessoryToPet = t.tuple(t.Model,t.table)
function PetHelper.AddAccessoryToPet(petModel , accessory)
    assert(tAddAccessoryToPet(petModel,accessory))
   
    local accessoryClone = AccessoryFolder:WaitForChild(accessory.Id):Clone()
    local part0 = petModel:FindFirstChild((accessory.Type).."Attachment",true)
    local part1 = accessoryClone:FindFirstChildWhichIsA("Attachment",true)
	local RigidConstraint = Instance.new("RigidConstraint")
	RigidConstraint.Attachment0 = part0
	RigidConstraint.Attachment1 = part1
	RigidConstraint.Parent = accessoryClone
	accessoryClone.Parent = petModel.PrimaryPart
end

local tRemoveAccessoryFromPet = t.tuple(t.Model,t.table)
function PetHelper.RemoveAccessoryFromPet(petModel , accessory: table)
    assert(tRemoveAccessoryFromPet(petModel,accessory))
    local accessoryToDestroy = petModel:FindFirstChild(accessory.Id,true)
    accessoryToDestroy:Destroy()
end

local tGetPetsWithFilter = t.tuple(t.table)
function PetHelper.GetPetsWithFilter(filter: table ): table
    assert( tGetPetsWithFilter(filter) )
    local filteredPets: table = {}
    for _, pet in pairs( PetData.Pets ) do 
        for filterName, filterValue in pairs( filter ) do 
            if( pet[filterName] == filterValue ) then
                table.insert(filteredPets, pet)
            end
        end
    end

    return filteredPets
end

local tGetRandomPetByRarity = t.tuple(t.string)
function PetHelper.GetRandomPetByRarity( rarity: string ): ()
    assert( tGetRandomPetByRarity(rarity) )
    local pets = PetHelper.GetPetsWithFilter({
        Rarity = rarity;
    })

    return pets[Randomize:NextInteger(1, #pets)]
end

local tGetNextRarityByName = t.tuple(t.string)
function PetHelper.GetNextRarityByName( rarity: string ): string
    assert( tGetNextRarityByName(rarity) )
    local rarityIndex: number = table.find(PetData.RaritiesInOrder, rarity)
    return PetData.RaritiesInOrder[ rarityIndex + 1]
end

local tGetWeightByRarity = t.tuple(t.string)
function PetHelper.GetWeightByRarity( rarity: string ): ()
    assert( tGetWeightByRarity(rarity) )
    return PetData.RarityWeights[ rarity ]
end

local tGetRarityByWeight = t.tuple(t.number)
function PetHelper.GetRarityByWeight( weight: number ): ()
    assert( tGetRarityByWeight(weight) )
    local rarity: string = "Core"

    for rarityName: string, rarityWeight: number in pairs( PetData.RarityWeights ) do
        if( weight > rarityWeight and rarityWeight > PetHelper.GetWeightByRarity(rarity) ) then 
            rarity = rarityName
        end
    end

    return rarity
end

local tGetNextShineByName = t.tuple(t.string)
function PetHelper.GetNextShineByName( shine: string ): string
    assert( tGetNextShineByName(shine))
    local shineIndex: number = table.find(PetData.ShinesInOrder, shine)
    return PetData.ShinesInOrder[ shineIndex + 1]
end

function PetHelper.GetGridPosition( currentCount, xSize, zSize, xCount: number ): ( number, number)
    local xPositionOffset = xSize
    local zPositionOffset = zSize

    currentCount -= 1
    local xPosition = (currentCount % xCount) * xPositionOffset - xSize
    local zPosition = math.floor(currentCount / xCount) * zPositionOffset + zPositionOffset

    return xPosition, zPosition
end

function PetHelper.GetPetOwner( pet: Instance ): ()
    local player: Player = game.Players:FindFirstChild( pet:GetAttribute("Owner") )

    if( not player ) then 
        warn(pet, "Owner does not exist")
    end

    return player
end

function PetHelper.GetPetGridCFrame( pet: Instance ): CFrame
    local owner = PetHelper.GetPetOwner( pet )
    if( not owner ) then 
        warn("Owner does not exist")
        return
    end

    local character = owner.Character or owner.CharacterAdded:Wait()

    if( not character ) then 
        warn(owner, "Character doesn't exist to spawn pet")
    end
    
    local x, z = PetHelper.GetGridPosition( pet:GetAttribute("PetOrder"), 3, 3, 3)
    return character:WaitForChild("HumanoidRootPart").CFrame * CFrame.new(Vector3.new(x, character:GetExtentsSize().Y / 2, z))
end

local tCheckIfPetLeveledUp = t.tuple(t.number,t.number)
function PetHelper.CheckIfPetLeveledUp( CurrentXp: number, currentLevel: number ): number
    assert( tCheckIfPetLeveledUp(CurrentXp,currentLevel))
    if currentLevel == PetMaximumLevel then
        return false
    end
    local NextLevelXp = math.min(10000, 50 * (2 ^ ((currentLevel+1)/7)))
	if CurrentXp >= NextLevelXp then
        return true
    else
        return false
    end
end

local tGetPetTraits = t.tuple(t.table)
function PetHelper.GetPetTraits(petData: table)
    assert(tGetPetTraits(petData))

    local traits = {}
    local petTraitsPerPurrsonality = PetData.PetTraitsPerPurrsonality[petData.Purrsonality]
    local traitsCount = PetData.PetTraitsCountForRarity[petData.Rarity]

    warn("traitsCount",traitsCount)
    warn(petData)

    local random: Random = Random.new()
    for count = 1, traitsCount, 1 do
        local index = random:NextInteger(1, #petTraitsPerPurrsonality)
        local randomTrait = petTraitsPerPurrsonality[index]
        table.insert(traits,randomTrait)
        table.remove(petTraitsPerPurrsonality,index)
    end
    return traits
end

return PetHelper