CPP = CPP or {}

local ENTITY = FindMetaTable("Entity")
local getTable = ENTITY.GetTable

function CPP.GetOwner(ent)
	return getTable(ent).CPPOwner
end

local setCreator = ENTITY.SetCreator

function ENTITY:SetCreator(ply)
	self:CPPISetOwner(ply)
	setCreator(self, ply)
end

hook.Add("PostGamemodeLoaded", "CPPOverrideFunctions", function()
	local PLAYER = FindMetaTable("Player")
	local addCount = PLAYER.AddCount

	function PLAYER:AddCount(str, ent)
		ent:CPPISetOwner(self)
		addCount(self, str, ent)
	end
end)

util.AddNetworkString("cpp_sendowners")

local network_entities = {}
local MAX_PLAYER_BITS = math.ceil(math.log(1 + game.MaxPlayers()) / math.log(2))

function ENTITY:CPPISetOwner(ply)
	if CPP.GetOwner(self) == ply then return end

	self.CPPOwner = ply
	self.CPPOwnerID = IsValid(ply) and ply:SteamID()
	table.insert(network_entities, self)

	if not timer.Exists("CPP_SendOwners") then
		timer.Create("CPP_SendOwners", 0, 1, function()
			net.Start("cpp_sendowners")

			for _, v in ipairs(network_entities) do
				if v:IsValid() and v:GetSolid() ~= SOLID_NONE and not v:IsEFlagSet(EFL_SERVER_ONLY) then
					net.WriteBool(true)
					net.WriteUInt(v:EntIndex(), MAX_EDICT_BITS)

					local owner = CPP.GetOwner(v)
					net.WriteUInt(IsValid(owner) and owner:EntIndex() or 0, MAX_PLAYER_BITS)
				end
			end

			network_entities = {}

			net.Broadcast()
		end)
	end
end

hook.Add("PlayerSpawnedEffect", "CPPAssignOwnership", function(ply, model, ent) ent:CPPISetOwner(ply) end)
hook.Add("PlayerSpawnedNPC", "CPPAssignOwnership", function(ply, ent) ent:CPPISetOwner(ply) end)
hook.Add("PlayerSpawnedProp", "CPPAssignOwnership", function(ply, model, ent) ent:CPPISetOwner(ply) end)
hook.Add("PlayerSpawnedRagdoll", "CPPAssignOwnership", function(ply, model, ent) ent:CPPISetOwner(ply) end)
hook.Add("PlayerSpawnedSENT", "CPPAssignOwnership", function(ply, ent) ent:CPPISetOwner(ply) end)
hook.Add("PlayerSpawnedSWEP", "CPPAssignOwnership", function(ply, ent) ent:CPPISetOwner(ply) end)
hook.Add("PlayerSpawnedVehicle", "CPPAssignOwnership", function(ply, ent) ent:CPPISetOwner(ply) end)

util.AddNetworkString("cpp_friends")

net.Receive("cpp_friends", function(len, ply)
	ply.CPPBuddies = ply.CPPBuddies or {}

	local target_ply = player.GetBySteamID(net.ReadString())
	if not target_ply or target_ply == ply then return end

	local value = net.ReadBool()
	ply.CPPBuddies[target_ply] = value or nil

	net.Start("cpp_friends")
	net.WritePlayer(ply)
	net.WritePlayer(target_ply)
	net.Broadcast()
end)

local load_queue = {}

hook.Add("PlayerInitialSpawn", "CPPInitializePlayer", function(ply)
	for _, v in ents.Iterator() do
		if v.CPPOwnerID == ply:SteamID() then
			v:CPPISetOwner(ply)
		end
	end

	load_queue[ply] = true
end)

hook.Add("StartCommand", "CPPInitializePlayer", function( ply, cmd )
	if load_queue[ply] and not cmd:IsForced() then
		load_queue[ply] = nil

		net.Start("cpp_sendowners")

		for _, v in ents.Iterator() do
			if IsValid(CPP.GetOwner(v)) and v:GetSolid() ~= SOLID_NONE and not v:IsEFlagSet(EFL_SERVER_ONLY) then
				net.WriteBool(true)
				net.WriteUInt(v:EntIndex(), MAX_EDICT_BITS)
				net.WriteUInt(IsValid(v.CPPOwner) and v.CPPOwner:EntIndex() or 0, MAX_PLAYER_BITS)
			end
		end

		net.Send(ply)
	end
end)

util.AddNetworkString("cpp_notify")

concommand.Add("CPP_Cleanup", function(ply, cmd, args, argstr)
	if not ply:IsAdmin() then return end

	local target_owner

	if args[1] == "disconnected" then
		for _, v in ents.Iterator() do
			local owner = CPP.GetOwner(v)

			if owner ~= nil and not owner:IsValid() then
				v:Remove()
			end
		end

		net.Start("cpp_notify")
		net.WriteString(ply:Nick())
		net.WriteString("disconnected")
		net.Broadcast()
	else
		local target_owner = player.GetBySteamID(args[1])
		if not target_owner then return end

		for _, v in ents.Iterator() do
			if v:IsWeapon() and v:GetOwner():IsValid() then
				continue
			end

			if CPP.GetOwner(v) == target_owner then
				v:Remove()
			end
		end

		net.Start("cpp_notify")
		net.WriteString(ply:Nick())
		net.WriteString(target_owner:Nick())
		net.Broadcast()
	end
end)

timer.Create("CPP_AutoCleanup", 300, 1, function()
	for _, v in ents.Iterator() do
		local owner = CPP.GetOwner(v)

		if owner ~= nil and not owner:IsValid() then
			v:Remove()
		end
	end
end)