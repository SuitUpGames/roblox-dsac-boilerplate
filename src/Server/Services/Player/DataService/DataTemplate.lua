local BUILD_VERSION: number = game.ReplicatedStorage.GameVersion.Value

local data = {
	build = BUILD_VERSION,
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
