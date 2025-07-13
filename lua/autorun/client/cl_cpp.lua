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

local toolpanel

local function OpenToolPanel(panel)
	if not toolpanel then toolpanel = panel end
	if not toolpanel then return end

	toolpanel:Clear()
	toolpanel:Help("Select friends:")

	for _, v in player.Iterator() do
		if v == LocalPlayer() then continue end

		local steamid = v:SteamID()
		local checkbox = toolpanel:CheckBox(string.format("%s(%s)", v:Nick(), steamid))
		checkbox:SetChecked(LocalPlayer().CPPBuddies and LocalPlayer().CPPBuddies[v] == true)

		function checkbox:OnChange(value)
			net.Start("cpp_friends")
			net.WriteString(steamid)
			net.WriteBool(value)
			net.SendToServer()
		end
	end

	toolpanel:Help("Cleanup players:")
	toolpanel:Button("Cleanup disconnected props", "CPP_Cleanup", "disconnected")

	for _, v in player.Iterator() do
		toolpanel:Button("Cleanup " .. v:Nick(), "CPP_Cleanup", v:SteamID())
	end
end

net.Receive("cpp_notify", function()
	notification.AddLegacy(net.ReadString() .. " cleaned up " .. net.ReadString() .. " props", NOTIFY_CLEANUP, 2)
	surface.PlaySound("buttons/button15.wav")
end)

net.Receive("cpp_friends", function()
	local ply = net.ReadPlayer()
	if not ply:IsValid() then return end

	ply.CPPBuddies = ply.CPPBuddies or {}
	ply.CPPBuddies[net.ReadPlayer()] = net.ReadBool() or nil
end)

hook.Add("SpawnMenuOpened", "CPPToolMenu", OpenToolPanel)
hook.Add("PopulateToolMenu", "CPPToolMenu", function() spawnmenu.AddToolMenuOption("Utilities", "User", "Classic_Prop_Protection", "Prop Protection", "", "", OpenToolPanel) end)