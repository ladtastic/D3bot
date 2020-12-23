local D3bot = D3bot
local CONCOMMAND = D3bot.CONCOMMAND

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Get new instance of a concommand object.
-- You have to add your own OnServer and OnClient methods to your concommand.
function CONCOMMAND:New(name)
	local obj = {
		Name = name,
		NameServer = "sv_" .. name
	}

	setmetatable(obj, self)
	self.__index = self

	-- Add concommands to client and server. The server one has a different name.
	if CLIENT then
		concommand.Add(obj.Name, function(ply, cmd, args, argStr) obj:_Callback(ply, cmd, args, argStr) end)
	end
	if SERVER then
		concommand.Add(obj.NameServer, function(ply, cmd, args, argStr) obj:_Callback(ply, cmd, args, argStr) end)
	end

	return obj
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Internal method: Callback that is called when the concommand is run.
function CONCOMMAND:_Callback(ply, cmd, args, argStr)
	-- Call any user supplied method to handle the concommand
	if SERVER and self.OnServer then
		self:OnServer(ply, cmd, args, argStr)
	end
	if CLIENT and self.OnClient then
		self:OnClient(ply, cmd, args, argStr)
	end

	-- Replicate concommand in server realm
	if CLIENT then
		-- Ignore ply, and call the server side concommand
		Entity(1):ConCommand(self.NameServer .. " " .. argStr)
	end
end