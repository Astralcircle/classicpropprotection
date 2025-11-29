CPP = CPP or {}

local ENTITY = FindMetaTable("Entity")
local getTable = ENTITY.GetTable

function CPP.GetOwner(ent)
	return getTable(ent).CPPOwner
end

-- Set owner function
util.AddNetworkString("cpp_sendowners")

local network_entities = {}

local function ProcessEntities(ent)
	if not ent.CPPNetworking then
		table.insert(network_entities, ent)
		ent.CPPNetworking = true
	end

	if not timer.Exists("CPP_SendOwners") then
		timer.Create("CPP_SendOwners", 0, 1, function()
			local created = false

			for _, ent in ipairs(network_entities) do
				if ent:IsValid() then
					if not ent:IsEFlagSet(EFL_SERVER_ONLY) then
						if not created then net.Start("cpp_sendowners") created = true end
						net.WriteUInt(ent:EntIndex(), MAX_EDICT_BITS)

						local owner = CPP.GetOwner(ent)
						net.WriteUInt(IsValid(owner) and owner:EntIndex() or 0, MAX_PLAYER_BITS)
					end

					ent.CPPNetworking = nil
				end
			end

			if created then
				net.Broadcast()
			end

			network_entities = {}
		end)
	end
end

function CPP.SetOwner(ent, ply)
	if CPP.GetOwner(ent) == ply then return end

	ent.CPPOwner = ply
	ent.CPPOwnerID = IsValid(ply) and ply:SteamID()
	ProcessEntities(ent)
end

hook.Add("OnEntityCreated", "CPP_RefreshWorld", function(ent)
	ProcessEntities(ent)
end)

-- Restore ownership for rejoined players
hook.Add("PlayerInitialSpawn", "CPP_InitializePlayer", function(ply)
	local steamid = ply:SteamID()
	timer.Remove("CPP_AutoCleanup" .. steamid)

	local created = false

	for _, ent in ents.Iterator() do
		local owner = CPP.GetOwner(ent)

		if IsValid(owner) and not ent:IsEFlagSet(EFL_SERVER_ONLY) then
			if not created then net.Start("cpp_sendowners") created = true end
			net.WriteUInt(ent:EntIndex(), MAX_EDICT_BITS)
			net.WriteUInt(owner:EntIndex(), MAX_PLAYER_BITS)
		end

		if ent.CPPOwnerID == steamid then
			CPP.SetOwner(ent, ply)
		end
	end

	if created then
		net.Send(ply)
	end
end)

-- Define ownership
hook.Add("PlayerSpawnedEffect", "CPP_AssignOwnership", function(ply, model, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedNPC", "CPP_AssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedProp", "CPP_AssignOwnership", function(ply, model, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedRagdoll", "CPP_AssignOwnership", function(ply, model, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedSENT", "CPP_AssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedSWEP", "CPP_AssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)
hook.Add("PlayerSpawnedVehicle", "CPP_AssignOwnership", function(ply, ent) CPP.SetOwner(ent, ply) end)

local cleanupAdd = cleanup.Add

function cleanup.Add(ply, type, ent)
	if IsValid(ent) then
		CPP.SetOwner(ent, ply)
	end

	return cleanupAdd(ply, type, ent)
end

local setCreator = ENTITY.SetCreator

function ENTITY:SetCreator(ply)
	if IsValid(ply) then
		CPP.SetOwner(self, ply)
	end

	return setCreator(self, ply)
end

hook.Add("PostGamemodeLoaded", "CPP_OverrideFunctions", function()
	local PLAYER = FindMetaTable("Player")
	local addCount = PLAYER.AddCount

	function PLAYER:AddCount(str, ent)
		CPP.SetOwner(ent, self)
		return addCount(self, str, ent)
	end
end)

-- Friends
util.AddNetworkString("cpp_friends")

net.Receive("cpp_friends", function(len, ply)
	local target_ply = player.GetBySteamID(net.ReadString())
	if not target_ply or target_ply == ply then return end

	local value = net.ReadBool()
	ply.CPPFriends = ply.CPPFriends or {}
	ply.CPPFriends[target_ply] = value or nil

	net.Start("cpp_friends")
	net.WriteBool(false)
	net.WriteString(ply:SteamID())
	net.WriteString(target_ply:SteamID())
	net.WriteBool(value)
	net.Broadcast()
end)

hook.Add("PlayerDisconnected", "CPP_CleanupFriends", function(ply)
	for _, friend in player.Iterator() do
		if friend.CPPFriends then
			friend.CPPFriends[ply] = nil
		end
	end

	net.Start("cpp_friends")
	net.WriteBool(true)
	net.WriteString(ply:SteamID())
	net.Broadcast()
end)

util.AddNetworkString("cpp_notify")

-- Cleanup
concommand.Add("CPP_Cleanup", function(ply, cmd, args, argstr)
	if not ply.CPPCanCleanup or not args[1] then return end

	if args[1] == "disconnected" then
		for _, ent in ents.Iterator() do
			local owner = CPP.GetOwner(ent)

			if owner ~= nil and not owner:IsValid() then
				ent:Remove()
			end
		end

		net.Start("cpp_notify")
		net.WriteString(ply:Nick())
		net.WriteString("disconnected")
		net.Broadcast()
	else
		local target_owner = player.GetBySteamID(args[1])
		if not target_owner then return end

		for _, ent in ents.Iterator() do
			if ent:IsWeapon() and ent:GetOwner():IsValid() then
				continue
			end

			if CPP.GetOwner(ent) == target_owner then
				ent:Remove()
			end
		end

		net.Start("cpp_notify")
		net.WriteString(ply:Nick())
		net.WriteString(target_owner:Nick())
		net.Broadcast()
	end
end)

-- Auto-cleanup + reset owners
hook.Add("PlayerDisconnected", "CPP_AutoCleanup", function(ply)
	local created = false

	for _, ent in ents.Iterator() do
		if CPP.GetOwner(ent) == ply and not ent:IsEFlagSet(EFL_SERVER_ONLY) then
			if not created then net.Start("cpp_sendowners") created = true end
			net.WriteUInt(ent:EntIndex(), MAX_EDICT_BITS)
			net.WriteUInt(0, MAX_PLAYER_BITS)
		end
	end

	if created then
		net.Broadcast()
	end

	local steamid = ply:SteamID()

	timer.Create("CPP_AutoCleanup" .. steamid, 300, 1, function()
		for _, ent in ents.Iterator() do
			if ent.CPPOwnerID == steamid then
				ent:Remove()
			end
		end
	end)
end)

-- CAMI rights
hook.Add("PlayerInitialSpawn", "CPP_SetupRights", function(ply)
	timer.Simple(0, function()
		if not ply:IsValid() then return end

		CAMI.PlayerHasAccess(ply, "CPP_Cleanup", function(bool)
			if bool then
				ply.CPPCanCleanup = true
			end
		end)

		CAMI.PlayerHasAccess(ply, "CPP_TouchEverything", function(bool)
			if bool then
				ply:SetNW2Bool("CPP_TouchEverything", true)
			end
		end)
	end)
end)
