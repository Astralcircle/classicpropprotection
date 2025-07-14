CPP = CPP or {}

-- Check for touch permission
function CPP.CanTouch(ply, ent)
	if ply:IsAdmin() or hook.Run("CPPCanTouch", ply, ent) then return true end
	local owner = CPP.GetOwner(ent)

	if IsValid(owner) then
		if SERVER then
			local friends = owner.CPPFriends
			if friends and friends[ply] then return true end
		else
			local friends = CPP.Friends[owner:SteamID()]
			if friends and friends[ply:SteamID()] then return true end
		end
	end

	return owner == ply
end

hook.Add("CanEditVariable", "CPPCheckPermission", function(ent, ply, key, val, editor)if not CPP.CanTouch(ply, ent) then return false end end)
hook.Add("CanPlayerUnfreeze", "CPPCheckPermission", function(ply, ent)if not CPP.CanTouch(ply, ent) then return false end end)
hook.Add("CanProperty", "CPPCheckPermission", function(ply, property, ent)if not CPP.CanTouch(ply, ent) then return false end end)
hook.Add("CanTool", "CPPCheckPermission", function(ply, tr, toolname, tool, button) if tr.Entity:IsValid() and not CPP.CanTouch(ply, tr.Entity) then return false end end)
hook.Add("PhysgunPickup", "CPPCheckPermission", function(ply, ent)if not CPP.CanTouch(ply, ent) then return false end end)

-- CPPI
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

local ENTITY = FindMetaTable("Entity")

function ENTITY:CPPIGetOwner()
	return CPP.GetOwner(self), CPPI.CPPI_NOTIMPLEMENTED
end

if SERVER then
	local PLAYER = FindMetaTable("Player")

	function PLAYER:CPPIGetFriends()
		local friends = self.CPPFriends
		if not friends then return {} end

		local tab = {}

		for k, v in pairs(friends) do
			table.insert(tab, k)
		end

		return tab
	end

	function ENTITY:CPPISetOwner(ply)
		CPP.SetOwner(self, ply)
	end

	function ENTITY:CPPICanTool(ply, toolmode)
		return CPP.CanTouch(ply, self)
	end

	function ENTITY:CPPICanPhysgun(ply)
		return CPP.CanTouch(ply, self)
	end

	function ENTITY:CPPICanProperty(ply, property)
		return CPP.CanTouch(ply, self)
	end

	function ENTITY:CPPICanUse()
		return true
	end

	function ENTITY:CPPICanDamage()
		return true
	end

	function ENTITY:CPPICanPickup()
		return true
	end

	function ENTITY:CPPICanPunt()
		return true
	end

	function ENTITY:CPPIDrive()
		return true
	end
end