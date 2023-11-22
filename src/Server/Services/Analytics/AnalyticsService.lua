--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local GameAnalytics = require(Packages.GameAnalytics)

local CURRENCIES = { "Coins" } -- List of all in-game currencies
local BUILD = "0.0.1" -- Game version
local GAME_KEY = "xxxxxxxxxxxxxxxx"
local SECRET_KEY = "xxxxxxxxxxxxxxxx"
local LOG_DEV_PRODUCT_PURCHASES = true
local RESOURCE_EVENT_TYPES = { -- (example: player gained coins in a mission is a
	-- "Reward" event type, player purchasing coins with Robux is a "Purchase" event type)
	"Reward",
	"Purchase",
	"Shop",
	"Loot",
	"Combat"
}
local GAMEPASS_IDS = {} -- List of all gamepass ids in the game
local CUSTOM_DIMENSIONS = {
	-- Uncomment and fill each dimension as needed
	-- Refer to https://docs.gameanalytics.com/advanced-tracking/custom-dimensions
	-- for more information about dimensions
	
	-- DIMENSION_01 = {};
	-- DIMENSION_02 = {};
	-- DIMENSION_03 = {};
}

--[=[
	@class AnalyticsService
	@server
	
	Author: Javi M (dig1t)
	
	Description: Knit service that handles GameAnalytics API requests.
	
	Make sure to change the API keys before using this service.
	Development keys should be used for testing and production keys should be used for release.
	
	Before using this service, make sure to configure the following variables inside AnalyticsService.lua:
	- CURRENCIES: List of all in-game currencies
	- BUILD: Game version
	- GAME_KEY: GameAnalytics game key
	- SECRET_KEY: GameAnalytics secret key
	- LOG_DEV_PRODUCT_PURCHASES: Whether or not to automatically log developer product purchases
	- RESOURCE_EVENT_TYPES: List of all resource event types (example: player gained coins in a mission is a
	"Reward" event type, player purchasing coins with Robux is a "Purchase" event type)
	- GAMEPASS_IDS: List of all gamepass ids in the game
	- CUSTOM_DIMENSIONS: Custom dimensions to be used in GameAnalytics (refer to [GameAnalytics docs](https://docs.gameanalytics.com/advanced-tracking/custom-dimensions) about dimensions)
	
	Events that happen during a mission (kills, deaths, rewards) should be
	tracked and logged after the event ends	to avoid hitting API limits.
	For example, if a player kills an enemy during a mission, the kill should be
	tracked and logged (sum of kills) at the end of the mission.
	
	Refer to [GameAnalytics docs](https://docs.gameanalytics.com/integrations/sdk/roblox/event-tracking) for more information and use cases.
	
	Using AnalyticsService to track events on the client:
	```lua
	-- Inside a LocalScript
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	
	local Packages = ReplicatedStorage.Packages
	local Knit = require(Packages.Knit)
	
	Knit.Start():await() -- Wait for Knit to start
	
	local AnalyticsService = Knit.GetService("AnalyticsService")
	
	local timesOpenedShop: number = 2
	
	Players.PlayerRemoving:Connect(function(player: Player)
		if player == Players.LocalPlayer then
			-- Before player leaves the game,
			-- log the number of times the shop was opened
			AnalyticsService.LogEvent:Fire({ -- Use AnalyticsService.LogEvent:Fire() to log a client-side event
				event: "UIEvent:OpenedShop",
				value: timesOpenedShop -- Number of times the player opened their shop
			})
		end
	end)
	```
]=]
local AnalyticsService = Knit.CreateService({
	Name = "AnalyticsService";
	Client = {
		LogEvent = Knit.CreateSignal();
	};
})

--[=[
	@interface PlayerEvent
	.userId number
	.event string
	.value number?
	@within AnalyticsService
]=]
type PlayerEvent = {
	userId: number,
	event: string,
	value: number?
}

--[=[
	@interface MarketplacePurchaseEvent
	.userId number
	.itemType string
	.id string
	.amount number?
	.cartType string
	@within AnalyticsService
]=]
type MarketplacePurchaseEvent = {
	userId: number,
	itemType: string,
	id: string,
	amount: number?,
	cartType: string
}

--[=[
	@interface PurchaseEvent
	.userId number
	.eventType string
	.itemId string
	.currency string
	.flowType string? -- Allowed flow types: "Sink", "Source" (defaults to "Sink")
	.amount number?
	@within AnalyticsService
	
	- Currency is the in-game currency type used, it must be defined in the CURRENCIES table
]=]
type PurchaseEvent = {
	userId: number,
	eventType: string, -- 1 by default
	itemId: string,
	currency: string, -- In-game currency type used
	flowType: string?, -- Sink or Source (Sink by default)
	amount: number?
}

--[=[
	@interface ResourceEvent
	.userId number
	.eventType string
	.itemId string
	.currency string
	.flowType string
	.amount number
	@within AnalyticsService
	
	- Currency is the in-game currency type used, it must be defined in the CURRENCIES table
]=]
type ResourceEvent = {
	userId: number,
	eventType: string,
	itemId: string, -- unique id of item (example: "Coins", "100 Coins",
	-- "Coin Pack", "Weapon Skin", "Red Loot Box", "Extra Life")
	currency: string,
	flowType: string,
	amount: number
}

--[=[
	@interface ErrorEvent
	.message string
	.severity string? -- Allowed severities: "Debug", "Info", "Warning", "Error", "Critical" (defaults to "Error")
	.userId number
	@within AnalyticsService
]=]
type ErrorEvent = {
	message: string,
	severity: string?,
	userId: number
}

--[=[
	@interface ProgressionEvent
	.userId number
	.status string -- Allowed statuses: "Start", "Fail", "Complete"
	.progression01 string
	.progression02 string?
	.progression03 string?
	.score number?
	@within AnalyticsService
]=]
type ProgressionEvent = {
	userId: number,
	status: string, -- Start, Fail, Complete
	progression01: string, -- Mission, Level, etc.
	progression02: string?, -- Location, etc.
	progression03: string?, -- Level, etc. (if used then progression02 is required)
	score: number?
}

function AnalyticsService:KnitInit()
	GameAnalytics:configureBuild(BUILD)
	
	if CUSTOM_DIMENSIONS.DIMENSION_01 then
		GameAnalytics:configureAvailableCustomDimensions01(CUSTOM_DIMENSIONS.DIMENSION_01)
	end
	
	if CUSTOM_DIMENSIONS.DIMENSION_02 then
		GameAnalytics:configureAvailableCustomDimensions02(CUSTOM_DIMENSIONS.DIMENSION_02)
	end
	
	if CUSTOM_DIMENSIONS.DIMENSION_03 then
		GameAnalytics:configureAvailableCustomDimensions03(CUSTOM_DIMENSIONS.DIMENSION_03)
	end
	
	GameAnalytics:configureAvailableResourceCurrencies(CURRENCIES)
	GameAnalytics:configureAvailableResourceItemTypes(RESOURCE_EVENT_TYPES)
	GameAnalytics:configureAvailableGamepasses(GAMEPASS_IDS)
	
	GameAnalytics:setEnabledInfoLog(false)
	GameAnalytics:setEnabledVerboseLog(false)
	GameAnalytics:setEnabledDebugLog(false)
	
	GameAnalytics:setEnabledAutomaticSendBusinessEvents(false)
	GameAnalytics:setEnabledReportErrors(false)
	
	GameAnalytics:initServer(GAME_KEY, SECRET_KEY)
end

function AnalyticsService:KnitStart()
	self.Client.LogEvent:Connect(function(player: Player, data: {
		event: string,
		value: number?
	})
		self:LogPlayerEvent({
			userId = player.UserId,
			event = data.event,
			value = data.value
		})
	end)
	
	MarketplaceService.PromptBundlePurchaseFinished:Connect(
		function(player: Player, bundleId: number, purchased: boolean)
			if not purchased then
				return
			end
			
			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "Bundle",
				id = bundleId,
				cartType = "PromptPurchase",
			})
		end
	)
	
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamePassId: number, purchased: boolean)
			if not purchased then
				return
			end
			
			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "GamePass",
				id = gamePassId,
				cartType = "PromptPurchase",
			})
		end
	)
	
	if LOG_DEV_PRODUCT_PURCHASES then
		MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(player: Player, productId: number, purchased: boolean)
				if not purchased then
					return
				end
				
				self:LogMarketplacePurchase({
					userId = player.UserId,
					itemType = "Product",
					id = productId,
					cartType = "PromptPurchase",
				})
			end
		)
	end
	
	MarketplaceService.PromptPurchaseFinished:Connect(
		function(player: Player, assetId: number, purchased: boolean)
			if not purchased then
				return
			end
			
			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "Asset",
				id = assetId,
				cartType = "PromptPurchase",
			})
		end
	)
	
	MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(
		function(player: Player, subscriptionId: string, didTryPurchasing: boolean)
			if not didTryPurchasing then
				return
			end
			
			self:LogMarketplacePurchase({
				userId = player.UserId,
				itemType = "Subscription",
				id = subscriptionId,
				cartType = "PromptPurchase",
			})
		end
	)
end

--[=[
	Used to track player events (example: player killed an enemy, player completed a mission, etc.)
	
	Examples
	```lua
	AnalyticsService:LogPlayerEvent({
		userId = player.UserId,
		event = "Player:KilledEnemy",
		value = 1 -- Killed 1 enemy
	})
	AnalyticsService:LogPlayerEvent({
		userId = player.UserId,
		event = "Player:CompletedMission",
		value = 1 -- Completed 1 mission
	})
	AnalyticsService:LogPlayerEvent({
		userId = player.UserId,
		event = "Player:Death",
		value = 1
	})
	```
]=]
function AnalyticsService:LogPlayerEvent(data: PlayerEvent)
	assert(typeof(data) == "table", "AnalyticsService.LogPlayerEvent - data is required")
	assert(data.userId, "AnalyticsService.LogPlayerEvent - userId is required")
	assert(data.event, "AnalyticsService.LogPlayerEvent - event is required")
	assert(
		data.value == nil or typeof(data.value) == "number",
		"AnalyticsService.LogPlayerEvent - value must be a number"
	)
	
	GameAnalytics:addDesignEvent(data.userId, {
		eventId = data.event,
		value = data.value
	})
end

--[=[
	This function should be called when a successful marketplace purchase is made
	such as a gamepass or developer product
	
	Set `LOG_DEV_PRODUCT_PURCHASES` to false inside AnalyticsService.lua if you prefer to log
	developer product purchases within MarketplaceService.ProcessReceipt
	
	```lua
	-- Inside MarketplaceService.ProcessReceipt
	-- before returning Enum.ProductPurchaseDecision.PurchaseGranted
	AnalyticsService:LogMarketplacePurchase({
		userId = player.UserId,
		itemType = "Product",
		id = 000000000, -- Developer product id
		cartType = "PromptPurchase",
	})
	```
]=]
function AnalyticsService:LogMarketplacePurchase(data: MarketplacePurchaseEvent)
	assert(typeof(data) == "table", "AnalyticsService.LogMarketplacePurchase - data is required")
	assert(data.userId, "AnalyticsService.LogMarketplacePurchase - userId is required")
	assert(data.itemType, "AnalyticsService.LogMarketplacePurchase - itemType is required")
	assert(data.id, "AnalyticsService.LogMarketplacePurchase - id is required")
	assert(data.cartType, "AnalyticsService.LogMarketplacePurchase - cartType is required")
	assert(data.userId, "AnalyticsService.LogMarketplacePurchase - userId is required")
	assert(
		data.amount == nil or typeof(data.amount) == "number",
		"AnalyticsService.LogMarketplacePurchase - amount must be a number"
	)
	
	GameAnalytics:addBusinessEvent(data.userId, {
		itemType = data.itemType,
		itemId = data.id,
		amount = data.amount or 1,
		cartType = data.cartType
	})
end

--[=[
	Shortcut function for LogResourceEvent
	Used to log in-game currency purchases
	
	Example Use:
	```lua
	AnalyticsService:LogPurchase({
		userId = player.UserId,
		eventType = "Shop",
		currency = "Coins",
		itemId = "Red Paintball Gun"
	})
	```
]=]
function AnalyticsService:LogPurchase(data: PurchaseEvent)
	assert(typeof(data) == "table", "AnalyticsService.LogPurchase - data is required")
	assert(typeof(data.userId) == "number", "AnalyticsService.LogPurchase - userId is required")
	assert(typeof(data.eventType) == "string", "AnalyticsService.LogPurchase - eventType is required")
	assert(
		table.find(RESOURCE_EVENT_TYPES, data.eventType),
		"AnalyticsService.LogPurchase - eventType " .. data.eventType .. " is invalid. Please define it in RESOURCE_EVENT_TYPES"
	)
	assert(data.itemId, "AnalyticsService.LogPurchase - itemId is required")
	assert(data.currency, "AnalyticsService.LogPurchase - currency is required")
	assert(
		table.find(CURRENCIES, data.currency),
		"AnalyticsService.LogPurchase - currency type is invalid"
	)
	assert(
		data.amount == nil or typeof(data.amount) == "number",
		"AnalyticsService.LogPurchase - amount is required"
	)
	assert(
		data.flowType == nil or GameAnalytics.EGAResourceFlowType[data.flowType],
		"AnalyticsService.LogPurchase - flow type is invalid"
	)
	
	self:LogResourceEvent({
		userId = data.userId,
		amount = data.amount or 1,
		currency = data.currency,
		flowType = (
			data.flowType == GameAnalytics.EGAResourceFlowType.Source and
			GameAnalytics.EGAResourceFlowType.Source
		) or (
			data.flowType == GameAnalytics.EGAResourceFlowType.Sink and
			GameAnalytics.EGAResourceFlowType.Sink
		) or
			GameAnalytics.EGAResourceFlowType.Sink,
		eventType = data.eventType,
		itemId = data.itemId
	})
end

--[=[
	Used to log in-game currency changes (example: player spent coins in a shop,
	player purchased coins, player won coins in a mission)
	
	Example Use:
	```lua
	-- Player purchased 100 coins with Robux
	AnalyticsService:LogPurchase({
		userId = player.UserId,
		eventType = "Purchase",
		currency = "Coins",
		itemId = "100 Coins"
	})
	```
]=]
function AnalyticsService:LogResourceEvent(data: ResourceEvent)
	assert(typeof(data) == "table", "AnalyticsService.LogResourceEvent - data is required")
	assert(typeof(data.userId) == "number", "AnalyticsService.LogResourceEvent - userId is required")
	assert(typeof(data.eventType) == "string", "AnalyticsService.LogResourceEvent - eventType is required")
	assert(
		table.find(RESOURCE_EVENT_TYPES, data.eventType),
		"AnalyticsService.LogResourceEvent - eventType " .. data.eventType .. " is invalid. Please define it in RESOURCE_EVENT_TYPES"
	)
	assert(data.itemId, "AnalyticsService.LogResourceEvent - itemId is required")
	assert(data.currency, "AnalyticsService.LogResourceEvent - currency is required")
	assert(
		table.find(CURRENCIES, data.currency),
		"AnalyticsService.LogResourceEvent - currency type is invalid"
	)
	assert(
		GameAnalytics.EGAResourceFlowType[data.flowType],
		"AnalyticsService.LogResourceEvent - flow type is invalid"
	)
	assert(
		typeof(data.amount) == "number",
		"AnalyticsService.LogResourceEvent - amount is required"
	)
	
	GameAnalytics:addResourceEvent(data.userId, {
		-- FlowType is Sink by default
		flowType = data.flowType,
		currency = data.currency,
		amount = data.amount,
		itemType = data.eventType,
		itemId = data.itemId
	})
end

function AnalyticsService:LogError(data: ErrorEvent)
	assert(typeof(data) == "table", "AnalyticsService.LogError - data is required")
	assert(data.userId, "AnalyticsService.LogError - userId is required")
	assert(data.message, "AnalyticsService.LogError - message is required")
	assert(
		data.severity == nil or GameAnalytics.EGAErrorSeverity[data.severity],
		"AnalyticsService.LogError - error severity type is invalid"
	)
	
	local errorSeverity: string = data.severity or GameAnalytics.EGAErrorSeverity.Error
	
	GameAnalytics:addErrorEvent(data.userId, {
		message = data.message,
		severity = GameAnalytics.EGAErrorSeverity[errorSeverity]
	})
end

--[=[
	Used to track player progression (example: player score in a mission or level)
	A progression can have up to 3 levels (example: Mission 1, Location 1, Level 1)
	
	Example:
	```lua
	AnalyticsService:LogProgression({
		userId = player.UserId,
		status = "Start",
		progression01 = "Mission X",
		progression02 = "Location X",
		score = 100 -- Started with score of 100
	})
	AnalyticsService:LogProgression({
		userId = player.UserId,
		status = "Complete",
		progression01 = "Mission X",
		progression02 = "Location X",
		score = 400 -- Completed the mission with a score of 400
	})
	```
	
	For more information on progression events, refer to [GameAnalytics docs](https://docs.gameanalytics.com/integrations/sdk/roblox/event-tracking?_highlight=teleportdata#progression) on progression.
]=]
function AnalyticsService:LogProgression(data: ProgressionEvent)
	assert(typeof(data) == "table", "AnalyticsService.LogProgression - data is required")
	assert(data.userId, "AnalyticsService.LogProgression - userId is required")
	assert(data.status, "AnalyticsService.LogProgression - status is required")
	assert(
		GameAnalytics.EGAProgressionStatus[data.status],
		"AnalyticsService.LogProgression - status type is invalid"
	)
	assert(
		data.score == nil or typeof(data.score) == "number",
		"AnalyticsService.LogProgression - score must be a number"
	)
	assert(
		typeof(data.progression01) == "string",
		"AnalyticsService.LogProgression - progression01 is required"
	)
	assert(
		data.progression02 == nil or typeof(data.progression02) == "string",
		"AnalyticsService.LogProgression - progression02 must be a string"
	)
	if data.progression03 ~= nil then
		assert(
			typeof(data.progression02) == "string",
			"AnalyticsService.LogProgression - progression02 is required if progression03 is used"
		)
	end
	
	GameAnalytics:addProgressionEvent(data.userId, {
		progressionStatus = GameAnalytics.EGAProgressionStatus[data.status],
		progression01 = data.progression01,
		progression02 = data.progression02,
		progression03 = data.progression03,
		score = data.score or 0
	})
end

return AnalyticsService
