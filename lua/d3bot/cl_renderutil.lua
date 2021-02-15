-- Copyright (C) 2020-2021 David Vogel
--
-- This file is part of D3bot.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

local D3bot = D3bot
local RENDER_UTIL = D3bot.RenderUtil

-- A list of matrices that rotate something to all 6 sides of a cube.
local matricesRot6Sided = {Matrix(), Matrix(), Matrix(), Matrix(), Matrix(), Matrix()}
matricesRot6Sided[1]:Rotate(Angle(0, 0, 0))
matricesRot6Sided[2]:Rotate(Angle(0, 180, 0))
matricesRot6Sided[3]:Rotate(Angle(0, 90, 0))
matricesRot6Sided[4]:Rotate(Angle(0, 270, 0))
matricesRot6Sided[5]:Rotate(Angle(90, 0, 0))
matricesRot6Sided[6]:Rotate(Angle(-90, 0, 0))

-- Vertices of an "arrow" pyramid.
local Draw3DArrowP1, Draw3DArrowP2, Draw3DArrowP3, Draw3DArrowP4, Draw3DArrowP5 = Vector(0,0,0), Vector(-1,1,1), Vector(-1,1,-1), Vector(-1,-1,-1), Vector(-1,-1,1)

---Draws a 3D arrow (pyramid) pointing in positive x direction.
---The tip is at Vector(0,0,0).
---@param color GColor
function RENDER_UTIL.Draw3DArrow(color)
	render.DrawQuad(Draw3DArrowP1, Draw3DArrowP2, Draw3DArrowP3, Draw3DArrowP4, color)
	render.DrawQuad(Draw3DArrowP1, Draw3DArrowP4, Draw3DArrowP5, Draw3DArrowP2, color)
	render.DrawQuad(Draw3DArrowP5, Draw3DArrowP4, Draw3DArrowP3, Draw3DArrowP2, color)
end

---Draws a spinning 3D cursor.
---This is basically 6 arrows pointing inwards.
---@param colorA GColor
---@param colorB GColor
function RENDER_UTIL.Draw3DCursor(colorA, colorB)
	local omega = CurTime() * math.pi * 2 * 0.5

	local mat = Matrix()
	mat:Rotate(Angle(math.sin(omega*0.8)*180, math.sin(omega*0.7)*180, math.sin(omega*0.6)*180))

	cam.PushModelMatrix(mat, true)
	for i, mat in ipairs(matricesRot6Sided) do
		local even = i % 2 == 0
		local mat = Matrix(mat)

		mat:Scale(Vector(5, 1, 1))
		--mat:Translate(Vector(math.sin(omega*3)*0.5-0.5, 0, 0))

		cam.PushModelMatrix(mat, true)
		RENDER_UTIL.Draw3DArrow(even and colorA or colorB)
		cam.PopModelMatrix()
	end
	cam.PopModelMatrix()
end

---Draws a spinning 3D cursor at given position.
---This is basically 6 arrows pointing inwards.
---@param pos GVector
---@param size number
---@param colorA GColor
---@param colorB GColor
function RENDER_UTIL.Draw3DCursorPos(pos, size, colorA, colorB)
	local omega = CurTime() * math.pi * 2 * 0.5

	local mat = Matrix()
	mat:Translate(pos)
	mat:Scale(Vector(size, size, size))
	mat:Rotate(Angle(math.sin(omega*0.8)*180, math.sin(omega*0.7)*180, math.sin(omega*0.6)*180))

	cam.PushModelMatrix(mat, true)
	for i, mat in ipairs(matricesRot6Sided) do
		local even = i % 2 == 0
		local mat = Matrix(mat)

		mat:Scale(Vector(5, 1, 1))
		--mat:Translate(Vector(math.sin(omega*3)*0.5-0.5, 0, 0))

		cam.PushModelMatrix(mat, true)
		RENDER_UTIL.Draw3DArrow(even and colorA or colorB)
		cam.PopModelMatrix()
	end
	cam.PopModelMatrix()
end

-- Vertices of a 2D arrow with a total length of 1.
-- It starts at Vector(0,0,0) and points to Vector(1,0,0) while facing upwards.
local Draw2DArrowP1, Draw2DArrowP2, Draw2DArrowP3, Draw2DArrowP4, Draw2DArrowP5, Draw2DArrowP6, Draw2DArrowP7 = Vector(-6/6, 1/6, 0), Vector(-4/6, 1/6, 0), Vector(-4/6, 3/6, 0), Vector(-0/6, 0/6, 0), Vector(-4/6, -3/6, 0), Vector(-4/6, -1/6, 0), Vector(-6/6, -1/6, 0)

---Draws a 2D arrow shape pointing in positive x direction, and facing upwards.
---The base is at Vector(-1,0,0), the tip is at Vector(0,0,0).
---It is one sided.
---@param color GColor
function RENDER_UTIL.Draw2DArrow(color)
	render.DrawQuad(Draw2DArrowP1, Draw2DArrowP2, Draw2DArrowP6, Draw2DArrowP7, color)
	render.DrawQuad(Draw2DArrowP3, Draw2DArrowP4, Draw2DArrowP5, Draw2DArrowP6, color)
end

---Draws a 2D arrow shape pointing in positive x direction, and facing upwards.
---The base is at Vector(-length,0,0), the tip is at Vector(length,0,0).
---It is one sided.
---@param color GColor
---@param length number
function RENDER_UTIL.Draw2DArrowLength(color, length)
	if length < 1 then
		local mat = Matrix()
		mat:Scale(Vector(length, 1, 1))
		cam.PushModelMatrix(mat, true)
		RENDER_UTIL.Draw2DArrow(color)
		cam.PopModelMatrix()
	else
		local offsetVector = Vector(1-length, 0, 0)
		render.DrawQuad(Draw2DArrowP1 + offsetVector, Draw2DArrowP2, Draw2DArrowP6, Draw2DArrowP7 + offsetVector, color)
		render.DrawQuad(Draw2DArrowP3, Draw2DArrowP4, Draw2DArrowP5, Draw2DArrowP6, color)
	end
end

---Draws a 2D arrow between two given positions.
---The arrow plane will be kept horizontal as much as possible.
---@param from GVector
---@param to GVector
---@param width number
---@param color GColor
function RENDER_UTIL.Draw2DArrowPos(from, to, width, color)
	local diff = to - from
	local length = diff:Length()

	local mat = Matrix()
	mat:Translate(to)
	mat:Rotate(diff:Angle())
	mat:Scale(Vector(width, width, width))

	cam.PushModelMatrix(mat, true)
	RENDER_UTIL.Draw2DArrowLength(color, length / width)
	cam.PopModelMatrix()
end

---Draws a two sided 2D arrow between two given positions.
---@param from GVector
---@param to GVector
---@param width number
---@param color GColor
function RENDER_UTIL.Draw2DArrow2SidedPos(from, to, width, color)
	local diff = to - from
	local length = diff:Length()

	for i = 0, 180, 180 do
		local mat = Matrix()
		mat:Translate(to)
		mat:Rotate(diff:Angle())
		mat:Rotate(Angle(0, 0, i))
		mat:Scale(Vector(width, width, width))
		cam.PushModelMatrix(mat, true)
		RENDER_UTIL.Draw2DArrowLength(color, length / width)
		cam.PopModelMatrix()
	end
end

---Draws a 2D arrow between two given positions.
---The arrow rotates around its axis.
---@param from GVector
---@param to GVector
---@param width number
---@param rotSpeed number @Rotational speed in full rotations per second.
---@param color GColor
function RENDER_UTIL.Draw2DArrow2SidedRotatingPos(from, to, width, rotSpeed, color)
	local diff = to - from
	local length = diff:Length()
	local angleOffset = CurTime() * 360 * rotSpeed

	for i = 0, 180, 180 do
		local mat = Matrix()
		mat:Translate(to)
		mat:Rotate(diff:Angle())
		mat:Rotate(Angle(0, 0, i + angleOffset))
		mat:Scale(Vector(width, width, width))
		cam.PushModelMatrix(mat, true)
		RENDER_UTIL.Draw2DArrowLength(color, length / width)
		cam.PopModelMatrix()
	end
end
