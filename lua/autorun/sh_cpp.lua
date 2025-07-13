CPP = CPP or {}

local ENTITY = FindMetaTable("Entity")

function ENTITY:CPPIGetOwner()
	return CPP.GetOwner(self), CPPI.CPPI_NOTIMPLEMENTED
end

function CPP.CanTouch(ply, ent)
	if ply:IsAdmin() then return true end
	local owner = CPP.GetOwner(ent)

	if IsValid(owner) then
		local buddies = owner.CPPBuddies or {}
		if buddies[ply] then return true end
	end

	return owner == ply
end

hook.Add("CanEditVariable", "CPPCheckPermission", function(ent, ply, key, val, editor)if not CPP.CanTouch(ply, ent) then return false end end)
hook.Add("CanPlayerUnfreeze", "CPPCheckPermission", function(ply, ent)if not CPP.CanTouch(ply, ent) then return false end end)
hook.Add("CanProperty", "CPPCheckPermission", function(ply, property, ent)if not CPP.CanTouch(ply, ent) then return false end end)
hook.Add("CanTool", "CPPCheckPermission", function(ply, tr, toolname, tool, button) if tr.Entity:IsValid() and not CPP.CanTouch(ply, tr.Entity) then return false end end)
hook.Add("PhysgunPickup", "CPPCheckPermission", function(ply, ent)if not CPP.CanTouch(ply, ent) then return false end end)

CPPI = CPPI or {}
CPPI.CPPI_NOTIMPLEMENTED = -1024
CPPI.CPPI_DEFER = -512

function CPPI:GetName()
	return "Classic Prop Protection"
end

function CPPI:GetVersion()
	return "1.0"
end

function CPPI:GetInterfaceVersion()
	return 1.3
end

local PLAYER = FindMetaTable("Player")

function PLAYER:CPPIGetFriends()
	local friends = self.CPPFriends
	if not friends then return {} end

	local tab = {}

	for k, v in pairs(friends) do
		tab[k] = v
	end

	return tab
end

if SERVER then
	function ENTITY:CPPICanTool(ply, toolmode)
		return CPP.CanTouch(ply, ent)
	end

	function ENTITY:CPPICanPhysgun(ply)
		return CPP.CanTouch(ply, ent)
	end

	function ENTITY:CPPICanProperty()
		return CPP.CanTouch(ply, ent)
	end

	function ENTITY:CPPICanUse(ply)
		return true
	end

	function ENTITY:CPPICanDamage(ply)
		return true
	end

	function ENTITY:CPPICanPickup(ply)
		return true
	end

	function ENTITY:CPPICanPunt(ply)
		return true
	end

	function ENTITY:CPPIDrive()
		return true
	end
end