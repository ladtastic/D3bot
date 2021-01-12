-- Copyright (C) 2020 David Vogel
-- 
-- This file is part of D3bot.
-- 
-- D3bot is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- D3bot is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with D3bot.  If not, see <http://www.gnu.org/licenses/>.

local D3bot = D3bot
local CONCOMMAND = D3bot.CONCOMMAND

------------------------------------------------------
--		Static
------------------------------------------------------

-- Make all methods and properties of the class available to its objects.
CONCOMMAND.__index = CONCOMMAND

-- Get new instance of a concommand object.
-- You have to add your own OnServer, OnClient or OnShared methods to your concommand object.
function CONCOMMAND:New(name, autocomplete, helpText, flags)
	local obj = {
		Name = name,
		NameServer = "sv_" .. name,
		Autocomplete = autocomplete,
		HelpText = helpText,
		Flags = flags
	}

	-- Instantiate
	setmetatable(obj, self)

	-- Add concommands to client and server. The server one has a different name.
	if CLIENT then
		concommand.Add(obj.Name, function(ply, cmd, args, argStr) obj:_Callback(ply, cmd, args, argStr) end, autocomplete, helpText, flags)
	end
	if SERVER then
		concommand.Add(obj.NameServer, function(ply, cmd, args, argStr) obj:_Callback(ply, cmd, args, argStr) end, autocomplete, helpText, flags)
	end

	return obj
end

------------------------------------------------------
--		Methods
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
	if self.OnShared then
		self:OnShared(ply, cmd, args, argStr)
	end

	-- Replicate concommand in server realm
	if CLIENT then
		-- Ignore ply, and call the server side concommand
		Entity(1):ConCommand(self.NameServer .. " " .. argStr)
	end
end

-- Returns the name of the concommand.
function CONCOMMAND:GetName()
	return self.Name
end

-- Returns the help text of the concommand.
function CONCOMMAND:GetHelpText()
	return self.HelpText or ""
end
