CPP = CPP or {}

local ENTITY = FindMetaTable("Entity")
local getTable = ENTITY.GetTable

function CPP.GetOwner(ent)
	return getTable(ent).CPPOwner
end

-- Set owner function
util.AddNetworkString("cpp_sendowners")

local network_entities = {}
local MAX_PLAYER_BITS = math.ceil(math.log(1 + game.MaxPlayers()) / math.log(2))

function CPP.SetOwner(ent, ply)
	if CPP.GetOwner(self) == ply then return end

	self.CPPOwner = ply
	self.CPPOwnerID = IsValid(ply) and ply:SteamID()
	table.insert(network_entities, self)

	if not timer.Exists("CPP_SendOwners") then
		timer.Create("CPP_SendOwners", 0, 1, function()
			net.Start("cpp_sendowners")

			for _, v in ipairs(network_entities) do
				if v:IsValid() and IsValid(CPP.GetOwner(v)) and v:GetSolid() ~= SOLID_NONE and not v:IsEFlagSet(EFL_SERVER_ONLY) then
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

-- Send touch data to new players
local load_queue = {}

hook.Add("PlayerInitialSpawn", "CPPInitializePlayer", function(ply)
	-- Restore ownership for rejoined players
	for _, v in ents.Iterator() do
		if v.CPPOwnerID == ply:SteamID() then
			CPP.SetOwner(v, ply)
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

-- Define ownership
hook.Add("PlayerSpawnedEffect", "CPPAssignOwnership", function(ply, model, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedNPC", "CPPAssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedProp", "CPPAssignOwnership", function(ply, model, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedRagdoll", "CPPAssignOwnership", function(ply, model, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedSENT", "CPPAssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedSWEP", "CPPAssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedVehicle", "CPPAssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)

local setCreator = ENTITY.SetCreator

function ENTITY:SetCreator(ply)
	CPP.SetOwner(self, ply)
	setCreator(self, ply)
end

hook.Add("PostGamemodeLoaded", "CPPOverrideFunctions", function()
	local PLAYER = FindMetaTable("Player")
	local addCount = PLAYER.AddCount

	function PLAYER:AddCount(str, ent)
		CPP.SetOwner(ent, self)
		addCount(self, str, ent)
	end
end)

-- Define ownership + antispam
local cleanupAdd = cleanup.Add

function cleanup.Add(ply, type, ent)
	if not IsValid(ply) or not IsValid(ent) then return cleanupAdd(ply, type, ent) end

	CPP.SetOwner(ent, ply)

	if type ~= "constraints" and type ~= "AdvDupe2" and not (AdvDupe2 and AdvDupe2.SpawningEntity) then
		if (ply.CPPBurstSpam or CurTime()) > CurTime() then
			local burstcount = (ply.CPPBurstCount or 0) + 1
			ply.CPPBurstCount = burstcount

			if burstcount >= 6 then
				CPP.Ghost(ent, ent:GetPhysicsObject())
			end
		else
			ply.CPPBurstCount = nil
		end

		ply.CPPBurstSpam = CurTime() + 0.5
	end

	cleanupAdd(ply, type, ent)
end

-- Ghosting
function CPP.Ghost(ent, phys)
	if ent.CPPGhosted then return end
	ent.CPPGhosted = true
	ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
	ent:DrawShadow(false)

	ent.CPPOldColor = ent:GetColor()
	ent:SetColor(Color(ent.CPPOldColor.r, ent.CPPOldColor.g, ent.CPPOldColor.b, ent.CPPOldColor.a - 155))
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)

	ent.CPPShouldUnfreeze = phys:IsMoveable()
	phys:EnableMotion(false)
end

hook.Add("OnPhysgunPickup", "CPPUnGhost", function(ply, ent)
	if not ent.CPPGhosted then return end
	ent.CPPGhosted = nil
	ent:DrawShadow(true)

	if ent.CPPOldColor then
		ent:SetColor(Color(ent.CPPOldColor.r, ent.CPPOldColor.g, ent.CPPOldColor.b, ent.CPPOldColor.a))
		ent.CPPOldColor = nil
	end

	ent:SetCollisionGroup(COLLISION_GROUP_NONE)

	if ent.CPPShouldUnfreeze then
		local phys = ent:GetPhysicsObject()

		if phys:IsValid() then
			phys:EnableMotion(true)
		end
	end
end)

-- Friends
util.AddNetworkString("cpp_friends")

net.Receive("cpp_friends", function(len, ply)
	ply.CPPFriends = ply.CPPFriends or {}

	local target_ply = player.GetBySteamID(net.ReadString())
	if not target_ply or target_ply == ply then return end

	local value = net.ReadBool()
	ply.CPPFriends[target_ply] = value or nil

	net.Start("cpp_friends")
	net.WritePlayer(ply)
	net.WritePlayer(target_ply)
	net.WriteBool(value)
	net.Broadcast()
end)

util.AddNetworkString("cpp_notify")

-- Cleanup
concommand.Add("CPP_Cleanup", function(ply, cmd, args, argstr)
	if not ply:IsAdmin() and not hook.Run("CPPCanCleanup", ply) then return end

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

-- Auto-cleanup
hook.Add("PlayerDisconnected", "CPP_AutoCleanup", function(ply)
	local steamid = ply:SteamID()

	timer.Simple(300, function()
		if player.GetBySteamID(steamid) then return end

		for _, v in ents.Iterator() do
			if v.CPPOwnerID == steamid then
				v:Remove()
			end
		end
	end)
end)