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
	if CPP.GetOwner(ent) == ply then return end

	ent.CPPOwner = ply
	ent.CPPOwnerID = IsValid(ply) and ply:SteamID()
	table.insert(network_entities, ent)

	if not timer.Exists("CPP_SendOwners") then
		timer.Create("CPP_SendOwners", 0, 1, function()
			local send_entities = {}

			for _, v in ipairs(network_entities) do
				if v:IsValid() then
					table.insert(send_entities, v)
				end
			end

			local send_count = #send_entities

			if send_count > 0 then
				net.Start("cpp_sendowners")

				for i = 1, send_count do
					local send_ent = send_entities[i]
					net.WriteUInt(send_ent:EntIndex(), MAX_EDICT_BITS)

					local owner = CPP.GetOwner(send_ent)
					net.WriteUInt(IsValid(owner) and owner:EntIndex() or 0, MAX_PLAYER_BITS)
					net.WriteBool(i == send_count)
				end

				net.Broadcast()
			end

			network_entities = {}
		end)
	end
end

-- Fix invalid owner for world entities
local world_entities = {}

hook.Add("OnEntityCreated", "CPPRefreshWorld", function(ent)
	table.insert(world_entities, ent)

	if not timer.Exists("CPP_RefreshWorld") then
		timer.Create("CPP_RefreshWorld", 0, 1, function()
			local send_entities = {}

			for _, v in ipairs(world_entities) do
				if v:IsValid() and IsValid(CPP.GetOwner(v)) then
					table.insert(send_entities, v)
				end
			end

			local send_count = #send_entities

			if send_count > 0 then
				net.Start("cpp_sendowners")

				for i = 1, send_count do
					local send_ent = send_entities[i]
					net.WriteUInt(send_ent:EntIndex(), MAX_EDICT_BITS)

					local owner = CPP.GetOwner(send_ent)
					net.WriteUInt(IsValid(owner) and owner:EntIndex() or 0, MAX_PLAYER_BITS)
					net.WriteBool(i == send_count)
				end

				net.Broadcast()
			end

			world_entities = {}
		end)
	end
end)

local load_queue = {}

-- Restore ownership for rejoined players
hook.Add("PlayerInitialSpawn", "CPPInitializePlayer", function(ply)
	for _, v in ents.Iterator() do
		if v.CPPOwnerID == ply:SteamID() then
			CPP.SetOwner(v, ply)
		end
	end

	load_queue[ply] = true
end)

-- Send touch data to new players
hook.Add("StartCommand", "CPPInitializePlayer", function( ply, cmd )
	if load_queue[ply] and not cmd:IsForced() then
		load_queue[ply] = nil

		local send_entities = {}

		for _, v in ents.Iterator() do
			if IsValid(CPP.GetOwner(v)) then
				table.insert(send_entities, v)
			end
		end

		local send_count = #send_entities

		if send_count > 0 then
			net.Start("cpp_sendowners")

			for i = 1, send_count do
				local send_ent = send_entities[i]
				net.WriteUInt(send_ent:EntIndex(), MAX_EDICT_BITS)
				net.WriteUInt(CPP.GetOwner(send_ent), MAX_PLAYER_BITS)
				net.WriteBool(i == send_count)
			end

			net.Send(ply)
		end
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

hook.Add("PostGamemodeLoaded", "CPPOverrideFunctions", function()
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

hook.Add("PlayerDisconnected", "CPPCleanupFriends", function(ply)
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
	if not ply.CPPCanCleanup then return end

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

	timer.Create("CPP_AutoCleanup_" .. steamid, 300, 1, function()
		if player.GetBySteamID(steamid) then return end

		for _, v in ents.Iterator() do
			if v.CPPOwnerID == steamid then
				v:Remove()
			end
		end
	end)
end)

-- CAMI rights
hook.Add("PlayerInitialSpawn", "CPPSetupRights", function(ply)
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
