-- Copyright (C) 2020-2021 David Vogel
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

------------------------------------------------------
--		Static
------------------------------------------------------

---@class D3botCONCOMMAND
---@field Name string @Client name of the concommand.
---@field NameServer string @Server name of the concommand. Can be accessed by client, but autocompletion doesn't work.
---@field Autocomplete function
---@field HelpText string @Text that is shown to the user in some way.
---@field Flags number @Modifier flags, see `concommand.Add`.
local CONCOMMAND = D3bot.CONCOMMAND
CONCOMMAND.__index = CONCOMMAND

---Get new instance of a concommand object.
---You have to add your own OnServer, OnClient or OnShared methods to your concommand object.
---@param name string @Client name of the concommand.
---@param autocomplete function @See `concommand.Add` for details.
---@param helpText string @Text that is shown to the user in some way.
---@param flags number @Modifier flags, see `concommand.Add`.
---@return table
function CONCOMMAND:New(name, autocomplete, helpText, flags)
	local obj = setmetatable({
		Name = name,
		NameServer = "sv_" .. name,
		Autocomplete = autocomplete,
		HelpText = helpText,
		Flags = flags,
	}, self)

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

---Internal method: Callback that is called when the concommand is run.
---@param ply GPlayer
---@param cmd string
---@param args string[]
---@param argStr string
function CONCOMMAND:_Callback(ply, cmd, args, argStr)
	-- Call any user supplied method to handle the concommand.
	if SERVER then
		self:OnServer(ply, cmd, args, argStr)
	end
	if CLIENT then
		self:OnClient(ply, cmd, args, argStr)
	end
	self:OnShared(ply, cmd, args, argStr)

	-- Replicate concommand in server realm.
	if CLIENT then
		-- Ignore ply, and call the server side concommand.
		LocalPlayer():ConCommand(self.NameServer .. " " .. argStr)
	end
end

---Client callback that has to be implemented by the user.
---@param ply GPlayer
---@param cmd string
---@param args string[]
---@param argStr string
function CONCOMMAND:OnClient(ply, cmd, args, argStr) end

---Server callback that has to be implemented by the user.
---@param ply GPlayer
---@param cmd string
---@param args string[]
---@param argStr string
function CONCOMMAND:OnServer(ply, cmd, args, argStr) end

---Shared callback that has to be implemented by the user.
---@param ply GPlayer
---@param cmd string
---@param args string[]
---@param argStr string
function CONCOMMAND:OnShared(ply, cmd, args, argStr) end

---Returns the name of the concommand.
---@return string
function CONCOMMAND:GetName()
	return self.Name
end

---Returns the help text of the concommand.
---@return string
function CONCOMMAND:GetHelpText()
	return self.HelpText or ""
end
