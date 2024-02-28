-- TradingService
-- Author(s): Jesse Appleton
-- Date: 11/02/2023

--[[
    
]]

---------------------------------------------------------------------

-- Types

type TradeEntry = {
	ID: string,
	InventoryType: string,
}

type PlayerTrade = {
	accepted: boolean,
	tradeId: string,
	entries: { TradeEntry },
	otherPlayer: Player,
}

-- Constants
local MAX_TRADE_ENTRIES = 3 -- Set to math.huge for no limiter
-- Knit
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Modules
local InventoryHelper = require(Knit.Helpers.InventoryHelper)
local TableUtil = require(Knit.Packages.TableUtil)

-- Roblox Services
local HttpService = game:GetService("HttpService")
-- Variables

-- Objects

---------------------------------------------------------------------

-- Creates trading service
local TradingService = Knit.CreateService({
	Name = "TradingService",
	Client = {
		RequestTrade = Knit.CreateSignal(),
		TradeAccepted = Knit.CreateSignal(),
		TradeCompleted = Knit.CreateSignal(),
		TradeCreated = Knit.CreateSignal(),
		EntryAddedToTrade = Knit.CreateSignal(),
		EntryBatchAddedToTrade = Knit.CreateSignal(),
		EntryRemovedFromTrade = Knit.CreateSignal(),
		EntryBatchRemovedFromTrade = Knit.CreateSignal(),
	},

	tradeIds = {},
	playersInTrade = {},
})

-- Creates new trade entry
local function CreateTradeEntry(tradeId: string, otherPlayer: Player): PlayerTrade
	return {
		accepted = false,
		tradeId = tradeId,
		entries = {},
		otherPlayer = otherPlayer,
	}
end

-- Checks if player is trading
function TradingService:IsPlayerInTrade(player: Player): boolean
	if self.playersInTrade[player.UserId] then
		return true
	end

	return false
end

-- Creates new trading transaction
function TradingService:CreateNewTrade(player1: Player, player2: Player): string?
	if self:IsPlayerInTrade(player1) or self:IsPlayerInTrade(player2) then
		-- Can't open a new trade if one of the players is in an active trade.
		return nil
	end

	local tradeId = HttpService:GenerateGUID()
	table.insert(self.tradeIds, tradeId)
	self.playersInTrade[player1.UserId] = CreateTradeEntry(tradeId, player2)
	self.playersInTrade[player2.UserId] = CreateTradeEntry(tradeId, player1)

	self.Client.TradeCreated:Fire(player1, player2.Name)
	self.Client.TradeCreated:Fire(player2, player1.Name)

	return tradeId
end

-- Adds specific entry to trade
function TradingService:AddEntryToTrade(player: Player, entryId: string, entryType: string): ()
	local tradeEntry = self.playersInTrade[player.UserId]
	if not tradeEntry then
		return
	end

	if #tradeEntry.entries < MAX_TRADE_ENTRIES then
		local entry: TradeEntry = {
			ID = entryId,
			InventoryType = entryType,
		}
		table.insert(tradeEntry.entries, entry)
	else
		warn("Maximum number of entries reached")
	end
end

-- Adds batch of entries to trade
function TradingService:AddBatchToTrade(player: Player, entries: { TradeEntry }): ()
	for _, entry: TradeEntry in pairs(entries) do
		self:AddEntryToTrade(player, entry.ID, entry.InventoryType)
	end
end

-- Removes entry from trade
function TradingService:RemoveEntryFromTrade(player: Player, entryId: string): ()
	local tradeEntry = self.playersInTrade[player.UserId]
	if not tradeEntry then
		return
	end

	local entryIndex = table.find(tradeEntry.entryIds, entryId)
	if entryIndex then
		table.remove(tradeEntry.entryIds, entryIndex)
	end
end

-- Removes batch of entries from trade
function TradingService:RemoveBatchFromTrade(player: Player, entryIds: { string }): ()
	for _, id in pairs(entryIds) do
		self:RemoveEntryFromTrade(player, id)
	end
end

-- Executes and completes trade
function TradingService:CompleteTrade(player1: Player, player2: Player): boolean
	local tradeEntry1: PlayerTrade = self.playersInTrade[player1.UserId]
	local tradeEntry2: PlayerTrade = self.playersInTrade[player2.UserId]

	if (not tradeEntry1 or not tradeEntry2) or (tradeEntry1.tradeId ~= tradeEntry2.tradeId) or not tradeEntry1.accepted or not tradeEntry2.accepted then
		return false
	end

	local function SwapInventoryEntries(player1: Player, player2: Player, entries1: { TradeEntry }, entries2: { TradeEntry }): ()
		local playerData1 = self.DataService:GetPlayerDataAsync(player1).Data
		local playerData2 = self.DataService:GetPlayerDataAsync(player2).Data

		for _, entry: TradeEntry in pairs(entries1) do
			local inventory1 = playerData1[entry.InventoryType]
			local entryCopy1 = TableUtil.Copy(inventory1[entry.ID])
			InventoryHelper.RemoveFromInventoryByGUID(inventory1, entry.ID)
			InventoryHelper.AddToInventory(playerData2[entry.InventoryType], entryCopy1)
			self.DataService:ReplicateTableIndex(player2, entry.InventoryType, entryCopy1.GUID)
		end

		for _, entry: TradeEntry in pairs(entries2) do
			local inventory2 = playerData2[entry.InventoryType]
			local entryCopy2 = TableUtil.Copy(inventory2[entry.ID])
			InventoryHelper.RemoveFromInventoryByGUID(inventory2, entry.ID)
			InventoryHelper.AddToInventory(playerData1[entry.InventoryType], entryCopy2)
			self.DataService:ReplicateTableIndex(player1, entry.InventoryType, entryCopy2.GUID)
		end
	end

	SwapInventoryEntries(player1, player2, tradeEntry1.entries, tradeEntry2.entries)

	self.TradeCompleted:Fire(player1)
	self.TradeCompleted:Fire(player2)

	return true
end

-- Player accepts trade
function TradingService:AcceptTrade(player: Player): boolean
	local tradeEntry: PlayerTrade = self.playersInTrade[player.UserId]
	local otherEntry = self.playersInTrade[tradeEntry.otherPlayer.UserId]
	if not tradeEntry or otherEntry then
		return false
	end

	tradeEntry.accepted = true
	self.Client.TradeAccepted:Fire(player)

	if otherEntry.accepted then
		self:CompleteTrade(player, tradeEntry.otherPlayer)
	end

	return true
end

-- Starts this trading service
function TradingService:KnitStart(): ()
	local function OnRequestTrade(player: Player, requestedName: string): ()
		local requestedPlayer: Player = game.Players:FindFirstChild(requestedName)

		if not requestedPlayer then
			warn(requestedName, "not a valid player")
		end

		self.Client.RequestTrade:Fire(requestedPlayer, player.Name)
	end

	local function OnTradeAccepted(player: Player): ()
		self:AcceptTrade(player)
	end

	local function OnEntryAddedToTrade(player: Player, entryId: string, entryType: string): ()
		self:AddEntryToTrade(player, entryId, entryType)
	end

	local function OnEntryBatchAddedToTrade(player: Player, entryIds: { string }): ()
		self:AddBatchToTrade(player, entryIds)
	end

	local function OnEntryRemovedFromTrade(player: Player, entryId: string): ()
		self:RemoveEntryFromTrade(player, entryId)
	end

	local function OnEntryBatchRemovedFromTrade(player: Player, entryIds: { string }): ()
		self:RemoveBatchFromTrade(player, entryIds)
	end

	self.Client.RequestTrade:Connect(OnRequestTrade)
	self.Client.TradeAccepted:Connect(OnTradeAccepted)
	self.Client.EntryAddedToTrade:Connect(OnEntryAddedToTrade)
	self.Client.EntryBatchAddedToTrade:Connect(OnEntryBatchAddedToTrade)
	self.Client.EntryRemovedFromTrade:Connect(OnEntryRemovedFromTrade)
	self.Client.EntryBatchRemovedFromTrade:Connect(OnEntryBatchRemovedFromTrade)
end

-- Sets up DataService
function TradingService:KnitInit(): ()
	self.DataService = Knit.GetService("DataService")
end

return TradingService
