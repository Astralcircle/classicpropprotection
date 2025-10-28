CPP = CPP or {}
CPP.Friends = {}
CPP.EntOwners = {}

function CPP.GetOwner(ent)
	local index = CPP.EntOwners[ent:EntIndex()]
	return index and Entity(index)
end

local MAX_PLAYER_BITS = math.ceil(math.log(1 + game.MaxPlayers()) / math.log(2))

net.Receive("cpp_sendowners", function()
	repeat
		local entindex, plyindex = net.ReadUInt(MAX_EDICT_BITS), net.ReadUInt(MAX_PLAYER_BITS)
		CPP.EntOwners[entindex] = plyindex == 0 and -1 or plyindex
	until net.ReadBool()
end)

net.Receive("cpp_notify", function()
	notification.AddLegacy(net.ReadString() .. " cleaned up " .. net.ReadString() .. " props", NOTIFY_CLEANUP, 2)
	surface.PlaySound("buttons/button15.wav")
end)

net.Receive("cpp_friends", function()
	if net.ReadBool() then
		local steamid = net.ReadString()
		CPP.Friends[steamid] = nil

		for _, friends in pairs(CPP.Friends) do
			friends[steamid] = nil
		end
	else
		local steamid = net.ReadString()
		CPP.Friends[steamid] = CPP.Friends[steamid] or {}
		CPP.Friends[steamid][net.ReadString()] = net.ReadBool() or nil
	end
end)

local draw_hud = CreateClientConVar("cpp_drawpropowners", "1", true)
local color_background = Color(0, 0, 0, 110)
local color_green = Color(0, 255, 0)
local color_red = Color(255, 0, 0)

-- HUD
hook.Add("HUDPaint", "CPPInfoBox", function()
	if not draw_hud:GetBool() then return end

	local ent = LocalPlayer():GetEyeTrace().Entity
	if not ent:IsValid() or ent:IsPlayer() then return end

	local owner = CPP.GetOwner(ent)
	draw.WordBox(4, 0, ScrH() / 2, IsValid(owner) and owner:Nick() or "world", "Default", color_background, CPP.CanTouch(LocalPlayer(), ent) and color_green or color_red)
end)

-- Spawnmenu
local clientpanel

CreateClientConVar("cpp_ignoreothersprops", "0", true, true)
CreateClientConVar("cpp_ignoreworldprops", "1", true, true)
CreateClientConVar("cpp_ignoreyourprops", "0", true, true)

function CPP.ClientMenu(panel)
	if not IsValid(clientpanel) then clientpanel = panel end
	if not IsValid(clientpanel) then return end

	clientpanel:Clear()
	clientpanel:Help("Client settings:")

	clientpanel:CheckBox("Draw props owners", "cpp_drawpropowners")
	clientpanel:CheckBox("Ignore other players props", "cpp_ignoreothersprops")
	clientpanel:CheckBox("Ignore world/disconnected props", "cpp_ignoreworldprops")
	clientpanel:CheckBox("Ignore your props", "cpp_ignoreyourprops")

	clientpanel:Help("Add friends:")

	local players = player.GetAll()
	local friends = CPP.Friends[LocalPlayer():SteamID()]
	table.sort(players, function(a, b) return a:Nick() < b:Nick() end)

	if #players > 1 then
		for _, v in ipairs(players) do
			if v == LocalPlayer() then continue end

			local steamid = v:SteamID()
			local checkbox = clientpanel:CheckBox(v:Nick())
			checkbox:SetChecked(friends and friends[steamid] ~= nil)

			function checkbox:OnChange(value)
				net.Start("cpp_friends")
				net.WriteString(steamid)
				net.WriteBool(value)
				net.SendToServer()
			end
		end
	else
		clientpanel:Help("<No players available>")
	end
end

local adminmenu

function CPP.AdminMenu(panel)
	if not IsValid(adminmenu) then adminmenu = panel end
	if not IsValid(adminmenu) then return end

	adminmenu:Clear()
	adminmenu:Help("Cleanup players:")
	adminmenu:Button("Cleanup disconnected props", "CPP_Cleanup", "disconnected")

	local players = player.GetAll()
	table.sort(players, function(a, b) return a:Nick() < b:Nick() end)

	for _, v in ipairs(players) do
		adminmenu:Button("Cleanup " .. v:Nick(), "CPP_Cleanup", v:SteamID())
	end
end

hook.Add("SpawnMenuOpened", "CPPToolMenu", function()
	if IsValid(clientpanel) then
		CPP.ClientMenu()
	end

	if IsValid(adminmenu) then
		CPP.AdminMenu()
	end
end)

hook.Add("PopulateToolMenu", "CPPToolMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "Prop Protection", "CPP_Cleanup", "Admin", "", "", CPP.AdminMenu)
	spawnmenu.AddToolMenuOption("Utilities", "Prop Protection", "CPP_Friends", "Client", "", "", CPP.ClientMenu)
end)
