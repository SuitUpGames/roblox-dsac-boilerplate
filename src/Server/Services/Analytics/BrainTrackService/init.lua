--[[
BrainTrackService/init.lua
Author : James (steelheart2022)
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
local brainTrackService = knit.CreateService({
	Name = "BrainTrackService",
	Client = {},
	start_time = os.time(),
})

brainTrackService.cache = {}
brainTrackService.cache_expiration = BrainTrackSettings.cache_expiration or 45

local function getCountry(player: Player)
	local success, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	return success and code or "NA"
end

local function iterPageItems(pages)
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

function brainTrackService:track(player, tracking)
	-- 	print('brainTrackService:track')
	-- 	print(self.playerPlatform)
	-- 	print(self.playerPlatform[player])
	-- 	print(player)
	-- 	print(tracking)
	if ("" == game.JobId) and not BrainTrackSettings.track_on_local and not BrainTrackSettings.debug then
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
			brainTrackService.cache[key]
			and (brainTrackService.cache_expiration > os.difftime(now, brainTrackService.cache[key]))
		then
		--print('limiting to 1 per ' .. brainTrackService.cache_expiration .. ' seconds. too many tracks on ' .. key)
		-- 		    print(brainTrackService.cache)
		else
			brainTrackService.cache[key] = now
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
					print(error)
				end
			end
	end)
end

function brainTrackService.Client:track(player, tracking)
	--     print("brainTrackService.Client:track(player, tracking)")
	--     print(player)
	--     print(tracking)
	return self.Server:track(player, tracking)
end

function brainTrackService.Client:setPlayerPlatform(player, IsTenFootInterface, TouchEnabled, MouseEnabled)
	self.Server:track(player, {
		event = "setPlayerPlatform",
		choice = HttpService:JSONEncode({ itfi = IsTenFootInterface, te = TouchEnabled, me = MouseEnabled }),
	})
	-- 	print('brainTrackService.Client:setPlayerPlatform')
	-- 	print(player)
	-- 	print(IsTenFootInterface)
	-- 	print(TouchEnabled)
	-- 	print(MouseEnabled)

	if IsTenFootInterface then
		self.Server.playerPlatform[player] = "console"
	elseif TouchEnabled and not MouseEnabled then
		self.Server.playerPlatform[player] = "mobile"
	else
		self.Server.playerPlatform[player] = "desktop"
	end
end

function brainTrackService:KnitInit()
	self.playerPlatform = {}
end

function brainTrackService:KnitStart()

	game.Players.PlayerMembershipChanged:Connect(function(player: Player)
		self:track(player, { event = "PlayerMembershipChanged", choice = player.MembershipType })
	end)

	-- track when come, go and die
	game.Players.PlayerAdded:Connect(function(player: Player)
		self:track(player, {
			event = "PlayerAdded",
			choice = HttpService:JSONEncode({
				FollowUserId = player.FollowUserId,
				AccountAge = player.AccountAge,
				MembershipType = player.MembershipType.Name,
			}),
		})

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

				--             print('has friend')
				--             print(item)
				--             self:track(player, {event = 'HasFriend', choice=HttpService:JSONEncode(item)})
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
	game.Players.PlayerRemoving:Connect(function(player: Player)
	    self:track(player, { event = "PlayerRemoving" })
	end)

	game:GetService("ScriptContext").Error:Connect(function(message, trace, script)
		--         print(script:GetFullName().." errored!")
		--         print("Reason: "..message)
		--         print("Trace: "..trace)
		self:track(nil, { event = "error", choice = trace, subchoice = message, scene = script:GetFullName() })
	end)

	spawn(function()
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
			wait(50)
		end
	end)
end

return brainTrackService
