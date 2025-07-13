CPP = CPP or {}
CPP.entOwners = {}

local MAX_PLAYER_BITS = math.ceil(math.log(1 + game.MaxPlayers()) / math.log(2))

net.Receive("cpp_sendowners", function()
	while net.ReadBool() do
		local entindex, plyindex = net.ReadUInt(MAX_EDICT_BITS), net.ReadUInt(MAX_PLAYER_BITS)
		CPP.entOwners[entindex] = plyindex == 0 and -1 or plyindex
	end
end)

function CPP.GetOwner(ent)
	local index = CPP.entOwners[ent:EntIndex()]
	return index and Entity(index)
end