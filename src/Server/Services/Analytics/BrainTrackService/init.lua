--[[
BrainTrackService/init.lua
Author : James (stinkoDad20x6)
Description : send tracked data to our braintracking on xpop in a good format.
track chat, friends, serverstats, player add and remove

usage : BrainTrackService:track(player, trackingData)
where trackingData is a dictionary that can have the following keys defined:
	'event','choice','subchoice','campaign','scene'
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local LocalizationService = game:GetService("LocalizationService")

local config = require(script.config)
local BrainTrackSettings = config.BrainTrackSettings

local knit = require(ReplicatedStorage.Packages.Knit)

local baseUrl = "https://xpop.poptropica.com/brain/track.php"
local BrainTrackService = knit.CreateService({
	Name = "BrainTrackService",
	Client = {},
	start_time = os.time(),
	BrainTrackSummaryEvent = {},
})

BrainTrackService.cache = {}
BrainTrackService.cache_expiration = BrainTrackSettings.cache_expiration or 45

function getCountry(player)
	local success, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	return success and code or "NA"
end

function iterPageItems(pages)
	return coroutine.wrap(function()
		local pagenum = 1
		while true do
			for _, item in ipairs(pages:GetCurrentPage()) do
				coroutine.yield(item, pagenum)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
			pagenum = pagenum + 1
		end
	end)
end

function player_name(player)
	if type(player) == "string" then
		return player
	end
	if player:IsA("Player") then
		return player.Name
	end
	warn("Unhanded variable type passed to player_name()", player, type(player))
	local success, result = pcall(function()
		return player.Name
	end)
	if success then
		return result
	end
	local success, result = pcall(function()
		return player .. ""
	end)
	if success then
		return result
	end
	return "unknownPlayer"
end

function BrainTrackService:SetSummaryEvent(player, event_name, data)
	local player_name = player_name(player)
	if not self.BrainTrackSummaryEvent[player_name] then
		self.BrainTrackSummaryEvent[player_name] = {}
	end
	self.BrainTrackSummaryEvent[player_name][event_name] = data
end

function BrainTrackService:GetSummaryEvent(player, event_name)
	local player_name = player_name(player)
	if not self.BrainTrackSummaryEvent[player_name] then
		warn("GetSummaryEvent player_folder not found for ", player_name)
		return nil
	end
	return self.BrainTrackSummaryEvent[player_name][event_name]
end

function BrainTrackService:TrackAndCleanSummaryEvents(player)
	local player_name = player_name(player)
	if self.BrainTrackSummaryEvent[player_name] then
		for k, v in self.BrainTrackSummaryEvent[player_name] do
			local tracking = { event = k, choice = v }
			if "table" == type(v) then
				for k2, v2 in v do
					tracking[k2] = v2
				end
			end
			self:track(player, tracking)
			if BrainTrackSettings.debug then
				print("track and delete", k, v)
			end
		end
		self.BrainTrackSummaryEvent[player_name] = nil
	end
end

function BrainTrackService:track(player, tracking)
	if (game:GetService("RunService"):IsStudio()) and not BrainTrackSettings.track_on_local and not BrainTrackSettings.debug then
		return
	end

	tracking["randomNumber"] = math.random()
	if (nil ~= player) and (nil ~= player.Name) then
		tracking["login"] = player.Name
		tracking["platform"] = self.playerPlatform[player]
		tracking["country"] = getCountry(player)
	elseif type(player) == "string" then
		tracking["login"] = player
	end

	tracking["brain"] = tracking["brain"] or BrainTrackSettings["brain"] or "roblox"
	tracking["cluster"] = tracking["cluster"] or BrainTrackSettings["cluster"] or game.Name
	tracking["campaign"] = tracking["campaign"] or BrainTrackSettings["campaign"] or game.GameId
	--     tracking['cookie'] = tracking['cookie'] or game.PlaceId ..':'.. game.PlaceVersion ..':' .. game.JobId .. ':' .. self.start_time
	tracking["cookie"] = tracking["cookie"] or game.PlaceId .. ":" .. game.PlaceVersion .. ":" .. game.JobId

	task.spawn(function()
		local data = ""
		local key = ""
		local now = os.time()
		for k, v in pairs(tracking) do
			if "boolean" == typeof(v) then
				v = v and "true" or "false"
			end
			if "string" ~= typeof(v) then
				v = HttpService:JSONEncode(v)
			end
			-- 		event = chat then don't trim the length
			local messageLength = (
				(
						"chat" == tracking["event"]
						or "playerChatService:onPlayerChatted" == tracking["event"]
						or "error" == tracking["event"]
					)
					and 9999
				or (("choice" == k) and 99 or 63)
			)
			data = data
				.. ("&%s=%s"):format(HttpService:UrlEncode(k), HttpService:UrlEncode(string.sub(v, 1, messageLength)))
			if "randomNumber" ~= k then
				key = key .. ("&%s=%s"):format(HttpService:UrlEncode(k), HttpService:UrlEncode(v))
			end
		end
		-- cache hit

		if
			BrainTrackService.cache[key]
			and (BrainTrackService.cache_expiration > os.difftime(now, BrainTrackService.cache[key]))
		then
		--print('limiting to 1 per ' .. BrainTrackService.cache_expiration .. ' seconds. too many tracks on ' .. key)
		-- 		    print(BrainTrackService.cache)
		else
			BrainTrackService.cache[key] = now
				data = data:sub(2) -- Remove the first &
				local url = baseUrl .. "?" .. data

				if BrainTrackSettings.debug then
					print("getting " .. url)
				end

				local success, error = pcall(function()
					local response = HttpService:RequestAsync({
						Url = url,
						Method = "GET",
						Headers = {
							["cookie"] = "PopSecret=Membership",
						},
					})
					--print("response=")
					--print(response)
				end)
				if not success then
					if (game:GetService("RunService"):IsStudio()) then
						print(error)
					else
						warn("ERROR sending brainTracking event", error)
					end
				end
			end
	end)
end

function BrainTrackService.Client:track(player, tracking)
	return self.Server:track(player, tracking)
end

function BrainTrackService.Client:SetSummaryEvent(player, event_name, data)
	return self.Server:SetSummaryEvent(player, event_name, data)
end

function BrainTrackService.Client:GetSummaryEvent(player, event_name)
	return self.Server:GetSummaryEvent(player, event_name)
end

function BrainTrackService.Client:setPlayerPlatform(player, IsTenFootInterface, TouchEnabled, MouseEnabled)
	self.Server:track(player, {
		event = "setPlayerPlatform",
		choice = HttpService:JSONEncode({ itfi = IsTenFootInterface, te = TouchEnabled, me = MouseEnabled }),
	})


	if IsTenFootInterface then
		self.Server.playerPlatform[player] = "console"
	elseif TouchEnabled and not MouseEnabled then
		self.Server.playerPlatform[player] = "mobile"
	else
		self.Server.playerPlatform[player] = "desktop"
	end
end

function BrainTrackService:KnitInit()
	self.playerPlatform = {}
end

function BrainTrackService:KnitStart()
	if ("YOUR GAME" == BrainTrackSettings.campaign) then
		warn("Please update campaign src/Server/Services/Analytics/BrainTrackService/config.lua to a unique human readable key")
		BrainTrackSettings.campaign = game.PlaceId
	end

	game.Players.PlayerMembershipChanged:Connect(function(player)
		self:track(player, { event = "PlayerMembershipChanged", choice = player.MembershipType })
	end)

	-- track when come, go and die
	game.Players.PlayerAdded:Connect(function(player)
		self:track(player, {
			event = "PlayerAdded",
			choice = HttpService:JSONEncode({
				FollowUserId = player.FollowUserId,
				AccountAge = player.AccountAge,
				MembershipType = player.MembershipType.Name,
			}),
		})
		self:SetSummaryEvent(player, "TotalTime", os.time())

		player.CharacterAdded:Connect(function(character)
			character.Humanoid.Died:Connect(function()
				self:track(player, { event = "PlayerDied" })
			end)
		end)

		player.Chatted:Connect(function(message)
			self:track(player, { event = "chat", choice = message })
		end)

		local success, response = pcall(function()
			local friendPages = game.Players:GetFriendsAsync(player.userId)
			local count = 0
			local countOnline = 0
			local countOnGame = 0
			local friendIds = ""
			local currentPlayers = {}

			for i, _player in pairs(game.Players:GetPlayers()) do
				-- print(_player)
				currentPlayers[_player.UserId] = true
			end

			for item, pageNo in iterPageItems(friendPages) do
				friendIds = friendIds .. item.Id .. ","
				count = count + 1
				if item.IsOnline then
					countOnline = countOnline + 1
				end
				if currentPlayers[item.Id] then
					countOnGame = countOnGame + 1
				end

			end
			self:track(player, {
				event = "FriendSummary",
				choice = friendIds,
				subchoice = HttpService:JSONEncode({
					c = count,
					co = countOnline,
					cog = countOnGame,
				}),
			})
		end)
		if not success then
			self:track(player, { event = "FriendSummary set up fail", message = response })
		end
	end)
	game.Players.PlayerRemoving:Connect(function(player)
	    self:track(player, { event = "PlayerRemoving" })
		local player_start_time = self:GetSummaryEvent(player, "TotalTime")
		self:SetSummaryEvent(player, "TotalTime", os.time() - player_start_time)
		self:TrackAndCleanSummaryEvents(player)
	end)

	game:GetService("ScriptContext").Error:Connect(function(message, trace, script)
		self:track(nil, { event = "error", choice = trace, subchoice = message, scene = script:GetFullName() })
	end)

	task.spawn(function()
		while true do
			local Stats = game:GetService("Stats")
			local mem = Stats:GetTotalMemoryUsageMb()
			local stat_summary = {
				cc = Stats.ContactsCount,
				dr = math.floor(1000 * Stats.DataReceiveKbps),
				ds = math.floor(1000 * Stats.DataSendKbps),
				hb = math.floor(1000 * Stats.HeartbeatTimeMs),
				ic = math.floor(Stats.InstanceCount / 1000),
				mp = math.floor(Stats.MovingPrimitivesCount / 1000),
				pr = math.floor(1000 * Stats.PhysicsReceiveKbps),
				ps = math.floor(1000 * Stats.PhysicsSendKbps),
				pst = math.floor(1000 * Stats.PhysicsStepTimeMs),
				pc = math.floor(Stats.PrimitivesCount / 1000),
			}
			self:track(nil, {
				event = "heartBeat",
				choice = HttpService:JSONEncode(stat_summary),
				subchoice = "mem:" .. mem,
				scene = os.time(),
			})
			task.wait(50)
		end
	end)
end

return BrainTrackService
