local BUILD_VERSION: number = 1007

-- local Knit = require(game.ReplicatedStorage.Packages.Knit)
-- local InventoryHelper = require(Knit.Helpers.InventoryHelper)
-- local PetHelper = require(Knit.Helpers.PetHelper)

local data = {
	UnlockedStages = {
		"Downtown",
		"Park",
		"Farm"
	},
	AvailableStages = {
		"Downtown",
	},
	CurrentRegion = "Downtown",
	Coins = 0,
	Pets = {},
	Pods = {},
	Quests = {},
	MaxEquip = 5,
	PityRolls = {},
	LoginTimes = 0,
	RedeeemdCodes = {},
	build = BUILD_VERSION,
	TutorialComplete = false,
	AvatarAccessories = {
		["FaceAccessory"] = {},
		["HatAccessory"] = {},
		["NeckAccessory"] = {},
		["BackAccessory"] = {},
		["MouthAccessory"] = {},
		["HeadAccessory"] = {},
	},
	Challenges = {},
	Achievements = {},
}

local function GetPlayerDataTemplate()
	local formattedData = {}
	for key, value in data do
		if type(value) == "function" then
			formattedData[key] = value()
		else
			formattedData[key] = value
		end
	end
	return formattedData
end

return GetPlayerDataTemplate()
