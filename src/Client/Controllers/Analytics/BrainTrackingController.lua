--[[
BrainTrackController.lua
Author : James (stinkoDad20x6)
Description : track keepAlive with position and some player stats.
]]

local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local LocalPlayer = Players.LocalPlayer
local DataController


local BrainTrackController = Knit.CreateController({
    Name = "BrainTrackController",
})

--generate probably unique key based upon location
function PostionToBase64Key(Position)
	local Base64Chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#"
	local PositionString = string.format("%0.4i", (Position.X % 10000))
		.. string.format("%0.4i", (Position.Y % 10000))
		.. string.format("%0.4i", (Position.Z % 10000))
	local ResultString = ""
	while 1 * PositionString > 0 do
		local ModResult = PositionString % 64
		ResultString = string.sub(Base64Chars, ModResult + 1, ModResult + 1) .. ResultString
		PositionString = math.floor(PositionString / 64)
	end
	return ResultString
end

--format so shorter than json and most significant data first and less likely to be truncated
function AbbrTable(Table)
	local ResultString = ""
	local SortingArray = {}
	for k, v in Table do
		SortingArray[#SortingArray + 1] = { k = k, v = v }
	end
	table.sort(SortingArray, function(a, b)
		return a.v > b.v
	end)
	for k, v in SortingArray do
		ResultString = ResultString .. v.k .. "=" .. v.v .. ","
	end
	return ResultString
end

function BrainTrackController:KnitInit()
    local BrainTrackService = Knit.GetService("BrainTrackService")
    DataController = Knit.GetController("DataController")
    task.spawn(function()
        while true do
            task.wait(50)
			local success, response = pcall(function()
            local PlayerName = game.Players.LocalPlayer.Name
            local Position = game.Players:waitForChild(PlayerName).Character.HumanoidRootPart.Position
            local choice = "NoData"
            if (DataController and DataController.Data) then
                --todo prioritize data and shorten
                choice = DataController.Data
            end
            BrainTrackService:track( {event = 'keepAlive',
              choice=choice,
              subchoice= math.floor(Position.X * 10) ..','.. math.floor(Position.Y * 10) ..','.. math.floor(Position.Z * 10)
            })
			end)
			if not success then
				BrainTrackService:track( {event = 'keepAlive'})
				warn("braintrack fails on  keepAlive. Please rewrite player position data and/or DataController")
			end
        end
    end)

    task.spawn(function()
        local HttpService = game:GetService("HttpService")
        local teleportData = game:GetService("ReplicatedFirst"):WaitForChild('Client'):WaitForChild('teleportData',10)
        if (nil ~= teleportData) then
            BrainTrackService:track({
                event = "LPArrivedTeleport",
                choice = HttpService:JSONEncode(teleportData or "no data"),
                scene = "fromBT",
            })
        end
    end)

	task.spawn(function()
		local logo_assets = {  }
		if 0 == #logo_assets then
			warn("no logos in impression tracking")
			return
		end
		local start_time = os.time()
		local asset_use_count = {}
		local impressionParts = {}
		for _, subPart in workspace:GetDescendants() do
			if "Decal" == subPart.Name then
				pcall(function()
					for _, logo_asset in logo_assets do
						if subPart.Texture:match(logo_asset) then
							impressionParts[#impressionParts + 1] = subPart.Parent
							asset_use_count[logo_asset] = 1 + (asset_use_count[logo_asset] or 0)
						end
					end
				end)
			end
		end

		print("impressionParts", impressionParts)
		print("asset_use_count", asset_use_count)
		for _, logo_asset in logo_assets do
			if not asset_use_count[logo_asset] then
				warn('logo asset "' .. logo_asset .. '" not found. Double check asset id')
			end
		end
		print("logo asset setup took ", (os.time() - start_time))

		local PlayerName = game.Players.LocalPlayer.Name

		local Camera = workspace:WaitForChild("Camera")
		local period = 1
		local threshold = 10
		local stud_tolerance = 100
		local reseting_summary = {}
		local total_summary = {}

		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(function(character)
				-- wait for root part to exit
				WaitFor.Child(character, "HumanoidRootPart"):andThen(function(hrp)
					-- while the hrp exists track the position and update Impressions
					while hrp do
						task.wait(period)

						-- update position
						local playerPos = hrp.Position

						-- iterate through all impression parts
						for i, subPart in impressionParts do
							local _, isOnScreen = Camera:WorldToScreenPoint(subPart.Position)
							if isOnScreen then
								if stud_tolerance > (playerPos - subPart.Position).Magnitude then
									local part_id = subPart.Name
											.. ":"
											.. math.floor(subPart.Position.x)
											.. ":"
											.. math.floor(subPart.Position.y)
											.. ":"
											.. math.floor(subPart.Position.z)
											.. ":"
											.. subPart.Parent.Name
											.. ":"
											.. subPart.Parent.Parent.Name
											.. (
												subPart.Parent.Parent.Parent
												and (":" .. subPart.Parent.Parent.Parent.Name)
											)
										or "" .. (subPart.Parent.Parent.Parent.Parent and (":" .. subPart.Parent.Parent.Parent.Parent.Name))
										or ""
									--print('looking at ', subPart, i, part_id)
									local short_part_id = math.floor(subPart.Position.x)
										.. ":"
										.. math.floor(subPart.Position.y)
										.. ":"
										.. math.floor(subPart.Position.z)
									short_part_id = PostionToBase64Key(subPart.Position)
									total_summary[short_part_id] = period + (total_summary[short_part_id] or 0)
									reseting_summary[part_id] = period + (reseting_summary[part_id] or 0)
									--print("reseting_summary[part_id]", reseting_summary[part_id])
									if threshold <= reseting_summary[part_id] then
										BrainTrackService:track({
											event = "ImageImpression",
											choice = part_id,
											subchoice = reseting_summary[part_id],
											scene = short_part_id,
											uniq = os.time(),
										})
										reseting_summary[part_id] = 0
									end
								else
									--print('NOT looking at ', subPart, i, (playerPos - subPart.Position).Magnitude)
								end
							end
						end

						BrainTrackService:SetSummaryEvent("SumImageImpression", AbbrTable(total_summary))
					end
				end)
			end)
		end)
	end)
end

return BrainTrackController