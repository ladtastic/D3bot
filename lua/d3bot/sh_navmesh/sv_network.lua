local D3bot = D3bot



------------------------------------------------------
--					Navmesh PubSub					--
------------------------------------------------------

local NAV_PUBSUB = D3bot.NavPubSub

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
