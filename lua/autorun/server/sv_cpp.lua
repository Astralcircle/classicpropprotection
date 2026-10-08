CPP = CPP or {}
CPP.TouchEverything = {}

local ENTITY = FindMetaTable("Entity")
local GetTable = ENTITY.GetTable

function CPP.GetOwner(ent)
	return GetTable(ent).CPPOwner
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

-- Prevent entindexes conflict
hook.Add("OnEntityCreated", "CPP_RefreshWorld", ProcessEntities)

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
local cleanupReplaceEntity = cleanup.ReplaceEntity

function cleanup.Add(ply, type, ent)
	if IsValid(ent) then
		CPP.SetOwner(ent, ply)
	end

	return cleanupAdd(ply, type, ent)
end

function cleanup.ReplaceEntity(from, to)
	if IsValid(to) then
		to:CPPISetOwner(from:CPPIGetOwner())
	else
		from:CPPISetOwner(nil)
	end

	return cleanupReplaceEntity(from, to)
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

-- Net message for misc stuff
util.AddNetworkString("cpp_misc")

-- Friends
net.Receive("cpp_misc", function(len, ply)
	local target_ply = player.GetBySteamID(net.ReadString())
	if not target_ply or target_ply == ply then return end

	local value = net.ReadBool()
	ply.CPPFriends = ply.CPPFriends or {}
	ply.CPPFriends[target_ply] = value or nil

	net.Start("cpp_misc")
	net.WriteUInt(3, 2)
	net.WriteBool(false)
	net.WriteString(ply:SteamID())
	net.WriteString(target_ply:SteamID())
	net.WriteBool(value)
	net.Broadcast()
end)

-- Cleanup
concommand.Add("CPP_Cleanup", function(ply, cmd, args, argstr)
	if not args[1] then return end

	local function CPP_Cleanup()
		if args[1] == "disconnected" then
			for _, ent in ents.Iterator() do
				local owner = CPP.GetOwner(ent)

				if owner ~= nil and not owner:IsValid() then
					ent:Remove()
				end
			end

			net.Start("cpp_misc")
			net.WriteUInt(2, 2)
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

			net.Start("cpp_misc")
			net.WriteUInt(2, 2)
			net.WriteString(ply:Nick())
			net.WriteString(target_owner:Nick())
			net.Broadcast()
		end
	end

	if CAMI then
		CAMI.PlayerHasAccess(ply, "CPP_Cleanup", function(bool)
			if bool and ply:IsValid() then
				CPP_Cleanup()
			end
		end)
	elseif ply:IsAdmin() then
		CPP_Cleanup()
	end
end)

-- Clear anything after player + cleanup timer
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

	local plyindex = ply:EntIndex()
	CPP.TouchEverything[plyindex] = nil

	net.Start("cpp_misc")
	net.WriteUInt(1, 2)
	net.WriteUInt(plyindex, MAX_PLAYER_BITS)
	net.WriteBool(false)
	net.Broadcast()

	for _, friend in player.Iterator() do
		if friend.CPPFriends then
			friend.CPPFriends[ply] = nil
		end
	end

	net.Start("cpp_misc")
	net.WriteUInt(3, 2)
	net.WriteBool(true)
	net.WriteString(ply:SteamID())
	net.Broadcast()

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
function CPP.CalculateCanTouch(ply)
	local function CanTouch(can_touch)
		can_touch = can_touch and true or nil
		CPP.TouchEverything[ply:EntIndex()] = can_touch

		net.Start("cpp_misc")
		net.WriteUInt(1, 2)
		net.WriteUInt(ply:EntIndex(), MAX_PLAYER_BITS)
		net.WriteBool(can_touch)
		net.Broadcast()
	end

	timer.Simple(0, function()
		if not ply:IsValid() then return end

		if CAMI then
			CAMI.PlayerHasAccess(ply, "CPP_TouchEverything", function(bool)
				if ply:IsValid() then
					CanTouch(bool)
				end
			end)
		else
			CanTouch(ply:IsAdmin())
		end
	end)
end

hook.Add("PlayerInitialSpawn", "CPP_SetupRights", CPP.CalculateCanTouch)
