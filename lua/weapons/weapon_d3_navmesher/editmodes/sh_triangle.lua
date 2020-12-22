AddCSLuaFile()

local D3bot = D3bot
local NAV_EDIT = D3bot.NavEdit
local EDIT_MODES = D3_NAVMESHER_EDIT_MODES

-- Add edit mode to list
EDIT_MODES.TriangleAddRemove = EDIT_MODES.TriangleAddRemove or {}
local THIS_EDIT_MODE = EDIT_MODES.TriangleAddRemove

-- General edit mode info.
THIS_EDIT_MODE.Name = "Create & Remove triangles"

------------------------------------------------------
--						Static						--
------------------------------------------------------

-- Set and overwrite current edit mode of the given weapon.
-- This will create an instance of the edit mode class, and store it in the weapon's EditMode field.
function THIS_EDIT_MODE:AssignToWeapon(wep)
	local mode = {}

	setmetatable(mode, self)
	self.__index = self

	wep.EditMode = mode

	return true
end

------------------------------------------------------
--						Methods						--
------------------------------------------------------

-- Left mouse button action.
function THIS_EDIT_MODE:PrimaryAttack(wep)
	if not IsFirstTimePredicted() then return true end
	if not CLIENT then return true end

	-- Get eye trace info
	local trRes = wep.Owner:GetEyeTrace()

	if not trRes.Hit then return false end
	wep.Weapon:EmitSound("buttons/blip1.wav")

	self.TempPoints = self.TempPoints or {}

	table.insert(self.TempPoints, trRes.HitPos)

	if #self.TempPoints == 3 then
		-- Edit server side navmesh
		NAV_EDIT.CreateTriangle3P(LocalPlayer(), self.TempPoints[1], self.TempPoints[2], self.TempPoints[3])

		-- Reset build mode and its state
		THIS_EDIT_MODE:AssignToWeapon(wep)
	end

	-- Coroutine for primary actions
	-- It's a bit overkill for just storing a few points, but it's more a proof of concept
	--[[if self.PrimaryCR and coroutine.status(self.PrimaryCR) == "dead" then self.PrimaryCR = nil end
	self.PrimaryCR = self.PrimaryCR or coroutine.create(function()
		print("TestA")

		coroutine.yield()

		print("TestB")
	end)
	coroutine.resume(self.PrimaryCR)--]]

	return true
end

-- Right mouse button action.
function THIS_EDIT_MODE:SecondaryAttack(wep)
	return true
end

-- Reload button action.
function THIS_EDIT_MODE:Reload(wep)
	-- Reset build mode and its state
	THIS_EDIT_MODE:AssignToWeapon(wep)

	return true
end

-- Client side drawing
function THIS_EDIT_MODE:PostDrawViewModel(wep, vm)
	cam.Start3D()

	-- Draw client side navmesh
	if D3bot and D3bot.Navmesh then
		D3bot.Navmesh:Render3D()
	end

	--[[ Test stuff

	--print(vm)
	local world = Entity(0)
	local surfaces = world:GetBrushSurfaces()
	for i, surf in ipairs(surfaces) do
		--if i > 100 then
		--	return
		--end

		local vertices = surf:GetVertices()
		for j, vertex in ipairs(vertices) do
			--if j > 100 then
			--	return
			--end

			render.DrawLine(vertex, vertex + Vector(10, 10, 10))
			--render.DrawSphere(vertex, 5, 3, 3, Color(255, 255, 255))
		end
	end
	--print(surfaces)

	--for i = 1, 10000, 1 do
	--	render.DrawLine(Vector(math.random(0, 100), math.random(0, 100), math.random(0, 100)), Vector(math.random(0, 100), math.random(0, 100), math.random(0, 100)))
	--end--]]

	cam.End3D()
end

--function THIS_EDIT_MODE:DrawHUD(wep)
--end
