--[[
TeleportDetect.client.lua
Author : James (stinkoDad20x6)
Description : track LocalPlayerArrivedFromTeleport event. It has to be in ReplicatedFirst to be early enough. Works
in tandem with BrainTrackController
]]
game:GetService("TeleportService").LocalPlayerArrivedFromTeleport:Connect(function(gui,data)
    local stringValue = Instance.new("StringValue")
    stringValue.Value = data or 'no data'
    stringValue.Name = 'teleportData'
    stringValue.Parent = script
end)