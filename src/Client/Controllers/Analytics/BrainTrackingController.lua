--[=[
@class BrainTrackingController
@client

Author: James (stinkoDad20x6)
Refactored by ArtemisTheDeer
Date: 11/13/2023
Project: roblox-dsac-boilerplate
Description : track keepAlive with position and some player stats.
]=]

--GetService calls
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--Module imports (Require)
local Knit: table = require(ReplicatedStorage.Packages.Knit)
local Promise: table = require(ReplicatedStorage.Packages.Promise)
local BrainTrackService: table
local DataController: table
local BrainTrackingController = Knit.CreateController({
	Name = "BrainTrackingController",
})

local CAMERA: Camera = workspace.CurrentCamera
--[=[
    @prop AD_IMPRESSION_STUD_RANGE number
    @within BrainTrackingController
    How close the player needs to be (From an ad impression part) for it to qualify as an impression
]=]
local AD_IMPRESSSION_STUD_RANGE: number = 100 -- How close the player needs to be to an ad for it to qualify as an impression
--[=[
    @prop AD_IMPRESSION_REPORT_THRESHOLD number
    @within BrainTrackingController
    How many impressions a specific ad part needs to have in order to send an impression event to the server
    Eg. AD_IMPRESSION_REPORT_THRESHOLD is 10, if the specific ad part is on the player's screen for > 10 seconds (Cumulative), it is reported to the server and then the threshold is reset to 0
]=]
local AD_IMPRESSION_REPORT_THRESHOLD: number = 10 -- How many impressions to show for a part before sending to the server
local LOCAL_PLAYER: Player = Players.LocalPlayer
local PLAYER_NAME: string = LOCAL_PLAYER.Name
local BASE_64_CHARS: string = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#"
--[=[
    @prop POSITION_REPORTING_TIME number
    @within BrainTrackingController
    How often to report the character's position to the server for tracking purposes
]=]
local POSITION_REPORTING_TIME: number = 50
--[=[
    @prop IMPRESSION_REPORTING_TIME number
    @within BrainTrackingController
    How often to check (In seconds) for ads that are present on the player's screen
]=]
local IMPRESSION_REPORTING_TIME: number = 1
--[=[
    @interface LOGO_ASSETS
    @within BrainTrackingController
    string

    An array of image IDs that should be tracked (Decals/textures should be located under parts tagged with BRAINTRACK_COLLECITONTAG)
    Image IDs can be defined here as strings, or added via BrainTrackingController:AddLogoToTrack(logoTexture: string)
]=]
local LOGO_ASSETS: table = {}
--[=[
    @prop BRAINTRACK_COLLECTIONTAG string
    @within BrainTrackingController
    The tag that CollectionService will use for keeping track of parts to track ad impressions with
]=]
local BRAINTRACK_COLLECTIONTAG: string = "ImpressionPart"

local impressionParts: table = {}
local rollingAdImpressions: table = {}
local totalAdImpressions: table = {}

--[=[
    Generate a unique key based upon location
    @private
    @param Position vector3 -- The input position to convert to a Base64 string
    @return Promise<T> -- Returns a promise that resolves w/a Base64 string
]=]
function BrainTrackingController:_positionToBase64Key(Position: Vector3): table
	return Promise.new(function(Resolve, Reject)
		local PositionString = table.concat({
			string.format("%0.4i", (Position.X % 10000)),
			string.format("%0.4i", (Position.Y % 10000)),
			string.format("%0.4i", (Position.Z % 10000)),
		})

		local ResultString = ""

		while 1 * PositionString > 0 do
			local ModResult = PositionString % 64
			ResultString = string.sub(BASE_64_CHARS, ModResult + 1, ModResult + 1) .. ResultString
			PositionString = math.floor(PositionString / 64)
		end

		Resolve(ResultString)
	end)
end

--[=[
    Convert table to a string (Better than json)
    @private
    @param totalSummary table -- The total_summary table
    @return string -- Returns an abbreviated table as a string
]=]
function BrainTrackingController:_abbreviateTable(totalSummary: table): string
	local ResultString = ""
	local SortingArray = {}

	for k, v in totalSummary do
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

--[=[
    Check to see if a logo part (For braintracking) has decals under it w/the relevant logos being tracked
    @private
    @param logoPart BasePart -- The logo object to check for decals
    @return nil
]=]
function BrainTrackingController:_trackPart(logoPart: BasePart): nil
	if not impressionParts[logoPart] then
		local impressionData = {
			_ads = {},
			_totalAds = 0,
			_isParentedToWorkspace = logoPart:IsDescendantOf(workspace),
			_ancestryConnection = nil,
		}

		impressionData._ancestryConnection = logoPart.AncestryChanged:Connect(function(_, newParent: Instance | nil)
			local isInWorkspace = newParent ~= nil and newParent:IsDescendantOf(workspace)

			if impressionData[logoPart] then
				impressionData[logoPart]._isParentedToWorkspace = isInWorkspace
			end
		end)

		for _, Decal in logoPart:GetDescendants() do
			if Decal:IsA("Decal") or Decal:IsA("Texture") then
				local selectedLogo
				local decalTexture = Decal.Texture

				for _, Logo in LOGO_ASSETS do
					if decalTexture:match(Logo) then
						selectedLogo = Logo
						break
					end
				end

				if not selectedLogo then
					continue
				end

				impressionData._totalAds += 1
				table.insert(impressionData._ads, { _logoObject = Decal, _logoID = selectedLogo })
			end
		end

		impressionData._shortPartID = self:_positionToBase64Key(logoPart.Position)

		--Formats as: PartName:X:Y:Z:Parent:ParentParent:ParentParentParent:ParentParentParentParent
		impressionData._longPartID = (logoPart.Name .. ":%c:%c:%c:%c:%s:%s:%s:%s"):format(
			math.floor(logoPart.X),
			math.floor(logoPart.Y),
			math.floor(logoPart.Z),
			logoPart.Parent.Name,
			logoPart.Parent.Parent.Name,
			logoPart.Parent.Parent.Parent and logoPart.Parent.Parent.Parent.Name or "",
			logoPart.Parent.Parent.Parent.Parent and logoPart.Parent.Parent.Parent.Parent.Name or ""
		)

		if #impressionData._ads == 0 then
			warn("Warning: BrainTrack object ", logoPart:GetFullName(), " does not have any logo decals under it")
		end

		impressionParts[logoPart] = impressionData
	end
end

--[=[
    Remove a logo part from the list of assets to check for ad visibility
    @private
    @param logoPart BasePart -- The logo object to check for decals
    @return nil
]=]
function BrainTrackingController:_untrackPart(logoPart: BasePart): nil
	if impressionParts[logoPart] then
		impressionParts[logoPart]._ancestryConnection:Disconnect()
		impressionParts[logoPart] = nil
	end
end

--[=[
    Report the player's current position to BrainTrackService
    @private
    @return Promise<T> -- Returns a promise that resolves if the position was reported successfully, and rejects if not
]=]
function BrainTrackingController:_reportPlayerPosition(): table
	return Promise.new(function(Resolve, Reject)
		if not LOCAL_PLAYER.Character or not LOCAL_PLAYER.Character:FindFirstChild("HumanoidRootPart") then
			return Reject("Character/HumanoidRootPart not found!")
		end

		Resolve(LOCAL_PLAYER.Character.HumanoidRootPart.Position, DataController and DataController.Data or "NoData")
	end)
		:andThen(function(Position: Vector3, Data: table | string)
			BrainTrackService:track({
				event = "keepAlive",
				choice = Data,
				subchoice = string.format(
					"%c,%c,%c",
					math.floor(Position.X * 10),
					math.floor(Position.Y * 10),
					math.floor(Position.Z * 10)
				),
			})
		end)
		:catch(function(Message: any)
			warn("braintrackcontroller failed on keepAlive ", Message)
			BrainTrackService:track({
				event = "keepAlive",
			})
		end)
end

--[=[
    Report the player's current ad impressions to BrainTrackService
    @private
    @return Promise<T> -- Returns a promise that resolves if ad impressions were successfully reported, and rejects if not
]=]
function BrainTrackingController:_reportImageImpressions(): table
	return Promise.new(function(Resolve, Reject)
		if not LOCAL_PLAYER.Character or not LOCAL_PLAYER.Character:FindFirstChild("HumanoidRootPart") then
			return Reject("Character/HumanoidRootPart not found!")
		end

		Resolve(LOCAL_PLAYER.Character.HumanoidRootPart.Position)
	end)
		:andThen(function(Position: Vector3)
			for _, impressionPart in impressionParts do
				if not impressionPart._isParentedToWorkspace or impressionPart._totalAds == 0 then
					continue
				end

				local impressionPosition = impressionPart.Position
				local _, isOnScreen = CAMERA:WorldToScreenPoint(impressionPosition)

				if isOnScreen then
					local adDistance = LOCAL_PLAYER:DistanceFromCharacter(impressionPosition)

					if adDistance > AD_IMPRESSSION_STUD_RANGE then
						continue
					end

					rollingAdImpressions[impressionPart._longPartID] = 1
						+ (rollingAdImpressions[impressionPart._longPartID] or 0)
					totalAdImpressions[impressionPart._shortPartID] = 1
						+ (totalAdImpressions[impressionPart._shortPartID] or 0)

					if rollingAdImpressions[impressionPart._longPartID] >= AD_IMPRESSION_REPORT_THRESHOLD then
						BrainTrackService:track({
							event = "ImageImpression",
							choice = impressionPart._longPartID,
							subchoice = rollingAdImpressions[impressionPart._longPartID],
							scene = impressionPart._shortPartID,
							uniq = os.time(),
						})

						rollingAdImpressions[impressionPart._longPartID] = 0
					end
				end
			end

			BrainTrackService:SetSummaryEvent("SumImageImpression", self:_abbreviateTable(totalAdImpressions))
		end)
		:catch(function(Message: any)
			warn("braintrackcontroller failed on reportImageImpressions ", Message)
			BrainTrackService:track({
				event = "keepAlive",
			})
		end)
end

--[=[
    Clears the list of ad parts with the controller and goes through the array of BRAINTRACK_COLLECTIONTAG items via CollectionService
    @private
    @return nil
]=]
function BrainTrackingController:_refreshAdsList(): nil
	--Disconnect ancestry changed connection (If connected), and then refresh all parts w/latest list of logos from CollectionService
	for _, Logo in impressionParts do
		if Logo._ancestryConnection then
			Logo._ancestryConnection:Disconnect()
			Logo._ancestryConnection = nil
		end
	end

	impressionParts = {}

	for _, Object in CollectionService:GetTagged(BRAINTRACK_COLLECTIONTAG) do
		self:_trackPart(Object)
	end
end

--[=[
    Adds a logo to be tracked (Via decal/texture ID) to the list of logos to be tracked
    @param logoTexture string -- The decal/texture ID of the logo we're tracking
    @return nil
]=]
function BrainTrackingController:AddLogoToTrack(logoTexture: string): nil
	if table.find(LOGO_ASSETS, logoTexture) then
		warn("Logo asset ", logoTexture, " is already being tracked")
		return
	end

	table.insert(LOGO_ASSETS, logoTexture)

	self:_refreshAdsList()
end

--[=[
    Initialize BrainTrackingController
    @return nil
]=]
function BrainTrackingController:KnitInit(): nil
	BrainTrackService = Knit.GetService("BrainTrackService")
	DataController = Knit.GetController("DataController")

	--Setup tracking of parts in game
	CollectionService:GetInstanceAddedSignal(BRAINTRACK_COLLECTIONTAG):Connect(function(Object: Instance)
		self:_trackPart(Object)
	end)

	CollectionService:GetInstanceRemovedSignal(BRAINTRACK_COLLECTIONTAG):Connect(function(Object: Instance)
		self:_untrackPart(Object)
	end)

	for _, Object in CollectionService:GetTagged(BRAINTRACK_COLLECTIONTAG) do
		self:_trackPart(Object)
	end
end

--[=[
    Start BrainTrackingController
    @return nil
]=]
function BrainTrackingController:KnitStart(): nil
	Promise.new(function(Resolve, Reject)
		local teleportData = ReplicatedFirst:WaitForChild("Client"):WaitForChild("teleportData")
		Resolve(teleportData)
	end):andThen(function(teleportData: string)
		if teleportData then
			BrainTrackService:track({
				event = "LPArrivedTeleport",
				choice = HttpService:JSONEncode(teleportData) or "no data",
				scene = "fromBT",
			})
		end
	end)

	local currentTime = 0 -- Debounce
	local keepAliveCheck = 0 -- Debounce
	local adImpressionCheck = 0 -- Debounce

	RunService.Heartbeat:Connect(function(DT: number)
		currentTime += DT

		if currentTime >= keepAliveCheck then
			keepAliveCheck = currentTime + POSITION_REPORTING_TIME
			self:_reportPlayerPosition()
		end

		if currentTime >= adImpressionCheck then
			adImpressionCheck = currentTime + IMPRESSION_REPORTING_TIME
			self:_reportImageImpressions()
		end
	end)
end

return BrainTrackingController
