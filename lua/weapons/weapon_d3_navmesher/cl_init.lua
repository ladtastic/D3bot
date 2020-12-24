include("shared.lua")
include("cl_viewscreen.lua")

function SWEP:PreDrawViewModel(vm) -- ZS doesn't call this with the weapon and ply parameters
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.PreDrawViewModel then return true end

	return editMode:PreDrawViewModel(self, vm)
end

function SWEP:PostDrawViewModel(vm) -- ZS doesn't call this with the weapon and ply parameters
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.PostDrawViewModel then return true end

	return editMode:PostDrawViewModel(self, vm)
end

function SWEP:DrawHUD()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.DrawHUD then return true end

	return editMode:DrawHUD(self)
end
