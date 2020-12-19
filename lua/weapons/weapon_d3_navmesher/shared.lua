AddCSLuaFile()

SWEP.PrintName = "D3navmesher"
SWEP.Author = "D3"
SWEP.Contact = ""
SWEP.Purpose = "Build and edit D3bot navmeshes"
SWEP.Instructions = ""

SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.UseHands = true

-- Be nice, precache the models
util.PrecacheModel(SWEP.ViewModel)
util.PrecacheModel(SWEP.WorldModel)

SWEP.ShootSound = Sound("Airboat.FireGunRevDown")

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.CanHolster = true
SWEP.CanDeploy = true

-- Load edit modes
D3_NAVMESHER_EDIT_MODES = D3_NAVMESHER_EDIT_MODES or {}
include("editmodes/triangle.lua")

function SWEP:Initialize()
	self:ChangeEditMode("TriangleAddRemove")
end

function SWEP:Deploy()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Deploy then return true end

	return editMode:Deploy(self)
end

function SWEP:Holster()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Holster then return true end

	return editMode:Holster(self)
end

function SWEP:PrimaryAttack()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.PrimaryAttack then return true end

	return editMode:PrimaryAttack(self)
end

function SWEP:SecondaryAttack()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.SecondaryAttack then return true end

	return editMode:SecondaryAttack(self)
end

function SWEP:Reload()
	local editMode = self.EditMode

	if not editMode then return true end
	if not editMode.Reload then return true end

	return editMode:Reload(self)
end

function SWEP:ChangeEditMode(modeIdentifier)
	local editMode = D3_NAVMESHER_EDIT_MODES[modeIdentifier]
	if not editMode then return false end

	return editMode:AssignToWeapon(self)
end
