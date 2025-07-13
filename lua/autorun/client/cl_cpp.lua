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

local color_background = Color(0, 0, 0, 110)
local color_green = Color(0, 255, 0)
local color_red = Color(255, 0, 0)

hook.Add("HUDPaint", "CPPInfoBox", function()
	local ent = LocalPlayer():GetEyeTrace().Entity
	if not ent:IsValid() then return end

	local owner = CPP.GetOwner(ent)
	draw.WordBox(4, 0, ScrH() / 2, IsValid(owner) and owner:Nick() or "world", "Default", color_background, CPP.CanTouch(LocalPlayer(), ent) and color_green or color_red)
end)