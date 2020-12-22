local D3bot = D3bot
local NAV_PUBSUB = D3bot.NavPubSub

------------------------------------------------------
--						Shared						--
------------------------------------------------------

--util.AddNetworkString("D3bot_")

------------------------------------------------------
--						Server						--
------------------------------------------------------

if SERVER then
	-- Subscribe the client of the player to navmesh change events.
	function NAV_PUBSUB:SubscribePlayer(ply)
		self.Subscribers = self.Subscribers or {}

		table.insert(self.Subscribers, ply)
		return true
	end

	-- Unsubscribe the client of the player from navmesh change events.
	function NAV_PUBSUB:UnsubscribePlayer(ply)
		if not self.Subscribers then return false end

		if not table.RemoveByValue(self.Subscribers, ply) then return false end
		return true
	end
end

------------------------------------------------------
--						Client						--
------------------------------------------------------

if CLIENT then

end
