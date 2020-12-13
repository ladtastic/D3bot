-- Credits for the ULX fix to C0nw0nk https://github.com/C0nw0nk/Garrys-Mod-Fake-Players/blob/f9561c3f8c3dc06dddedac92dfaf437af21a9d83/addons/fakeplayers/lua/autorun/server/sv_fakeplayers.lua#L217
if (ULib and ULib.bans) then
	--ULX has some strange bug / issue with NextBot's and Player Authentication.
	--[[
	[ERROR] Unauthed player
	  1. query - [C]:-1
	   2. fn - addons/ulx-v3_70/lua/ulx/modules/slots.lua:44
		3. unknown - addons/ulib-v2_60/lua/ulib/shared/hook.lua:110
	]]
	--Fix above error by adding acception for bots to the ulxSlotsDisconnect hook.
	hook.Add(
		"PlayerDisconnected",
		"ulxSlotsDisconnect",
		function(ply)
			--If player is bot.
			if ply:IsBot() then
				--Do nothing.
				return
			end
		end
	)
end
