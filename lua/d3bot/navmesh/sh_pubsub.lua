-- PubSub, server side navmesh sends change events to this, and they will be distributed to clients that are registered as subscribers.
-- Basically server --> client communication.

local D3bot = D3bot
local NAV_PUBSUB = D3bot.NavPubSub
local NAV_MAIN = D3bot.NavMain
local NAV_MESH = D3bot.NAV_MESH
local NAV_EDGE = D3bot.NAV_EDGE
local NAV_TRIANGLE = D3bot.NAV_TRIANGLE

------------------------------------------------------
--						Shared						--
------------------------------------------------------

------------------------------------------------------
--						Server						--
------------------------------------------------------

if SERVER then
	-- Subscribe the client of the player to navmesh change events.
	function NAV_PUBSUB:SubscribePlayer(ply)
		self.Subscribers = self.Subscribers or {}

		table.insert(self.Subscribers, ply)

		-- Send main navmesh to new subscriber
		local navmesh = NAV_MAIN:ForceNavmesh()
		if navmesh then
			self:SendNavmeshToSubs(navmesh, ply)
		else
			self:DeleteNavmeshFromSubs(ply)
		end

		return true
	end

	-- Unsubscribe the client of the player from navmesh change events.
	-- Make sure this is called before a player leaves the server.
	function NAV_PUBSUB:UnsubscribePlayer(ply)
		if not self.Subscribers then return false end

		self:DeleteNavmeshFromSubs(ply)

		if not table.RemoveByValue(self.Subscribers, ply) then return false end
		return true
	end

	-- Sends the navmesh to all subscribers or to the optional plys parameter which can be a player or a table of players.
	function NAV_PUBSUB:SendNavmeshToSubs(navmesh, plys)
		plys = plys or self.Subscribers
		if not plys then return end

		local navTable = navmesh:MarshalToTable()
		local navTableJSON = util.TableToJSON(navTable)
		local navTableJSONCompressed = util.Compress(navTableJSON)

		-- TODO: Allow for more than 64kB of navmesh data by chunking
		net.Start("D3bot_Nav_PubSub_Navmesh")
		net.WriteUInt(navTableJSONCompressed:len(), 16)
		net.WriteData(navTableJSONCompressed, navTableJSONCompressed:len())
		net.Send(plys)
	end
	util.AddNetworkString("D3bot_Nav_PubSub_Navmesh")

	-- Removes the navmeshes from all subscribers or from the optional plys parameter which can be a player or a table of players.
	function NAV_PUBSUB:DeleteNavmeshFromSubs(plys)
		plys = plys or self.Subscribers
		if not plys then return end

		net.Start("D3bot_Nav_PubSub_NavmeshDelete")
		net.Send(plys)
	end
	util.AddNetworkString("D3bot_Nav_PubSub_NavmeshDelete")

	-- Sends a given edge to all the subscribers.
	function NAV_PUBSUB:SendEdgeToSubs(edge)
		if not self.Subscribers then return end

		net.Start("D3bot_Nav_PubSub_Edge")
		net.WriteTable(edge:MarshalToTable())
		net.Send(self.Subscribers)
	end
	util.AddNetworkString("D3bot_Nav_PubSub_Edge")

	-- Deletes a given edge from all the subscribers.
	function NAV_PUBSUB:DeleteEdgeFromSubs(id)
		if not self.Subscribers then return end

		net.Start("D3bot_Nav_PubSub_EdgeDelete")
		net.WriteTable(id)
		net.Send(self.Subscribers)
	end
	util.AddNetworkString("D3bot_Nav_PubSub_EdgeDelete")

	-- Sends a given triangle to all the subscribers.
	function NAV_PUBSUB:SendTriangleToSubs(triangle)
		if not self.Subscribers then return end

		net.Start("D3bot_Nav_PubSub_Triangle")
		net.WriteTable(triangle:MarshalToTable())
		net.Send(self.Subscribers)
	end
	util.AddNetworkString("D3bot_Nav_PubSub_Triangle")

	-- Deletes a given triangle from all the subscribers.
	function NAV_PUBSUB:DeleteTriangleFromSubs(id)
		if not self.Subscribers then return end

		net.Start("D3bot_Nav_PubSub_TriangleDelete")
		net.WriteTable(id)
		net.Send(self.Subscribers)
	end
	util.AddNetworkString("D3bot_Nav_PubSub_TriangleDelete")
end

------------------------------------------------------
--						Client						--
------------------------------------------------------

if CLIENT then
	net.Receive("D3bot_Nav_PubSub_Navmesh",
		function(len)
			local navTableJSONCompressed = net.ReadData(net.ReadUInt(16))
			local navTableJSON = util.Decompress(navTableJSONCompressed)
			local navTable = util.JSONToTable(navTableJSON)
			NAV_MAIN:SetNavmesh(NAV_MESH:NewFromTable(navTable))
		end
	)

	net.Receive("D3bot_Nav_PubSub_NavmeshDelete",
		function(len)
			NAV_MAIN:SetNavmesh(nil)
		end
	)

	net.Receive("D3bot_Nav_PubSub_Edge",
		function(len)
			local navmesh = NAV_MAIN:GetNavmesh()
			NAV_EDGE:NewFromTable(navmesh, net.ReadTable())
		end
	)

	net.Receive("D3bot_Nav_PubSub_EdgeDelete",
		function(len)
			local navmesh = NAV_MAIN:GetNavmesh()
			local edge = navmesh:FindEdgeByID(net.ReadTable())
			if edge then edge:Delete() end
		end
	)

	net.Receive("D3bot_Nav_PubSub_Triangle",
		function(len)
			local navmesh = NAV_MAIN:GetNavmesh()
			NAV_TRIANGLE:NewFromTable(navmesh, net.ReadTable())
		end
	)

	net.Receive("D3bot_Nav_PubSub_TriangleDelete",
		function(len)
			local navmesh = NAV_MAIN:GetNavmesh()
			local triangle = navmesh:FindTriangleByID(net.ReadTable())
			if triangle then triangle:Delete() end
		end
	)
end
