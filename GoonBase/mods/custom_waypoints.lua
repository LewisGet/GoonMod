----------
-- Payday 2 GoonMod, Weapon Customizer Beta, built on 12/30/2014 6:10:13 PM
-- Copyright 2014, James Wilkinson, Overkill Software
----------

-- Mod Definition
local Mod = class( BaseMod )
Mod.id = "CustomWaypoints"
Mod.Name = "Custom Waypoints"
Mod.Desc = "Allows players to set waypoints for themselves and friends"
Mod.Requirements = {}
Mod.Incompatibilities = {}

Hooks:Add("GoonBaseRegisterMods", "GoonBaseRegisterMutators_" .. Mod.id, function()
	GoonBase.Mods:RegisterMod( Mod )
end)

if not Mod:IsEnabled() then
	return
end

-- Custom Waypoints
_G.GoonBase.CustomWaypoints = _G.GoonBase.CustomWaypoints or {}
local CustomWaypoints = _G.GoonBase.CustomWaypoints
CustomWaypoints.MenuID = "goonbase_custom_waypoints_menu"
CustomWaypoints.PlaceWaypointName = "GoonBasePlaceWaypoint"
CustomWaypoints.RemoveWaypointName = "GoonBaseRemoveWaypoint"
CustomWaypoints.CustomKeys = {
	PLACE = GoonBase.Options.CustomWaypoints ~= nil and GoonBase.Options.CustomWaypoints.PlaceWaypoint or "k",
	REMOVE = GoonBase.Options.CustomWaypoints ~= nil and GoonBase.Options.CustomWaypoints.RemoveWaypoint or "l"
}

-- Network 
CustomWaypoints.Network = {}
CustomWaypoints.Network.PlaceWaypoint = "CustomWaypointPlace"
CustomWaypoints.Network.RemoveWaypoint = "CustomWaypointRemove"

-- Options
if GoonBase.Options.CustomWaypoints == nil then
	GoonBase.Options.CustomWaypoints = {}
	GoonBase.Options.CustomWaypoints.PlaceWaypoint = "k"
	GoonBase.Options.CustomWaypoints.RemoveWaypoint = "l"
	GoonBase.Options.CustomWaypoints.ShowDistance = true
end

-- Localization
local Localization = GoonBase.Localization
Localization.OptionsMenu_CustomWaypointMenuTitle = "Custom Waypoints"
Localization.OptionsMenu_CustomWaypointMenuMessage = "Change settings for your customizable waypoints"
Localization.OptionsMenu_CustomWaypointKeybindPlace = "Place Waypoint"
Localization.OptionsMenu_CustomWaypointKeybindRemove = "Remove Waypoint"
Localization.OptionsMenu_CustomWaypointShowDistanceTitle = "Show Distance on Waypoints"
Localization.OptionsMenu_CustomWaypointShowDistanceMessage = "Show how far away you are from custom waypoints"

-- Updates
Hooks:Add("GameSetupUpdate", "GameSetupUpdate_" .. Mod:ID(), function(t, dt)
	CustomWaypoints:UpdateBindings()
end)

function CustomWaypoints:UpdateBindings()

	local self = CustomWaypoints
	if self._input == nil then
		self._input = Input:keyboard()
	end
	if managers.hud:chat_focus() then
		return
	end

	local place_key = CustomWaypoints.CustomKeys.PLACE
	if not string.is_nil_or_empty(place_key) and self._input:pressed(Idstring(place_key)) then
		CustomWaypoints:SetWaypoint()
	end

	local remove_key = CustomWaypoints.CustomKeys.REMOVE
	if not string.is_nil_or_empty(remove_key) and self._input:pressed(Idstring(remove_key)) then
		CustomWaypoints:RemoveWaypoint()
	end

end

-- Custom Key Set
Hooks:Add("CustomizeControllerOnKeySet", "CustomizeControllerOnKeySet_" .. Mod:ID(), function(item)

	if item._name == CustomWaypoints.PlaceWaypointName then
		CustomWaypoints.CustomKeys.PLACE = item._input_name_list[1]
		CustomWaypoints:SaveBindings()
	end

	if item._name == CustomWaypoints.RemoveWaypointName then
		CustomWaypoints.CustomKeys.REMOVE = item._input_name_list[1]
		CustomWaypoints:SaveBindings()
	end

end)

function CustomWaypoints:SaveBindings()
	GoonBase.Options.CustomWaypoints.PlaceWaypoint = CustomWaypoints.CustomKeys.PLACE
	GoonBase.Options.CustomWaypoints.RemoveWaypoint = CustomWaypoints.CustomKeys.REMOVE
	GoonBase.Options:Save()
end

-- Menu
Hooks:Add("MenuManagerSetupCustomMenus", "MenuManagerSetupCustomMenus_" .. Mod:ID(), function(menu_manager, menu_nodes)
	GoonBase.MenuHelper:NewMenu( CustomWaypoints.MenuID )
end)

Hooks:Add("MenuManagerSetupGoonBaseMenu", "MenuManagerSetupGoonBaseMenu_" .. Mod:ID(), function( menu_manager )

	-- Menu button
	GoonBase.MenuHelper:AddButton({
		id = "custom_waypoint_menu_button",
		title = "OptionsMenu_CustomWaypointMenuTitle",
		desc = "OptionsMenu_CustomWaypointMenuMessage",
		next_node = CustomWaypoints.MenuID,
		menu_id = "goonbase_options_menu"
	})

	-- Keybinds
	GoonBase.MenuHelper:AddKeybinding({
		id = "custom_waypoint_menu_keybind_place",
		title = managers.localization:text("OptionsMenu_CustomWaypointKeybindPlace"),
		connection_name = CustomWaypoints.PlaceWaypointName,
		button = CustomWaypoints.CustomKeys.PLACE,
		binding = CustomWaypoints.CustomKeys.PLACE,
		menu_id = CustomWaypoints.MenuID,
		priority = 10
	})

	GoonBase.MenuHelper:AddKeybinding({
		id = "custom_waypoint_menu_keybind_remove",
		title = managers.localization:text("OptionsMenu_CustomWaypointKeybindRemove"),
		connection_name = CustomWaypoints.RemoveWaypointName,
		button = CustomWaypoints.CustomKeys.REMOVE,
		binding = CustomWaypoints.CustomKeys.REMOVE,
		menu_id = CustomWaypoints.MenuID,
		priority = 9
	})

	-- Show Distance
	MenuCallbackHandler.toggle_custom_waypoint_distance = function(this, item)
		GoonBase.Options.CustomWaypoints.ShowDistance = item:value() == "on" and true or false
		GoonBase.Options:Save()
	end

	GoonBase.MenuHelper:AddDivider({
		id = "custom_waypoint_menu_divider",
		menu_id = CustomWaypoints.MenuID,
		size = 16,
		priority = 2,
	})

	GoonBase.MenuHelper:AddToggle({
		id = "toggle_custom_waypoint_distance",
		title = "OptionsMenu_CustomWaypointShowDistanceTitle",
		desc = "OptionsMenu_CustomWaypointShowDistanceMessage",
		callback = "toggle_custom_waypoint_distance",
		value = GoonBase.Options.CustomWaypoints.ShowDistance,
		menu_id = CustomWaypoints.MenuID,
		priority = 1,
	})

end)

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenus_" .. Mod:ID(), function(menu_manager, mainmenu_nodes)
	mainmenu_nodes[CustomWaypoints.MenuID] = GoonBase.MenuHelper:BuildMenu( CustomWaypoints.MenuID )
end)

-- Waypoints
function CustomWaypoints:_AddWaypoint( waypoint_name, pos, color_id )
	managers.hud:add_waypoint(
		"CustomWaypoint_" .. waypoint_name,
		{
			icon = "infamy_icon",
			distance = GoonBase.Options.CustomWaypoints.ShowDistance,
			position = pos,
			no_sync = false,
			present_timer = 0,
			state = "present",
			radius = 50,
			color = tweak_data.preplanning_peer_colors[color_id or 1],
			blend_mode = "add"
		} 
	)
end

function CustomWaypoints:_RemoveWaypoint( waypoint_name )
	managers.hud:remove_waypoint("CustomWaypoint_" .. waypoint_name)
end

function CustomWaypoints:SetWaypoint()

	if managers.player:player_unit() == nil then
		return
	end

	local psuccess, perror = pcall(function()
		
		local pos = GetPlayerAimPos( managers.player:player_unit() )
		if not pos then
			return
		end

		CustomWaypoints:_AddWaypoint( "localplayer", pos, GoonBase.Network:LocalPeerID() )

		pos = Vector3.ToString( pos )
		GoonBase.Network:SendToPeers( CustomWaypoints.Network.PlaceWaypoint, pos )

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end

function CustomWaypoints:RemoveWaypoint()

	local psuccess, perror = pcall(function()

		GoonBase.Network:SendToPeers( CustomWaypoints.Network.RemoveWaypoint, "" )
		CustomWaypoints:_RemoveWaypoint( "localplayer" )

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end

function CustomWaypoints:NetworkPlace( player, position )

	local psuccess, perror = pcall(function()
		
		local ply_name = GoonBase.Network:GetNameFromPeerID(player)
		local pos = string.ToVector3(position)
		if pos ~= nil then
			CustomWaypoints:_AddWaypoint( ply_name, pos, player )
		end

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end

function CustomWaypoints:NetworkRemove(player)

	local psuccess, perror = pcall(function()
		
		local ply_name = GoonBase.Network:GetNameFromPeerID(player)
		CustomWaypoints:_RemoveWaypoint( ply_name )

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end

-- Networked Data
Hooks:Add("NetworkReceivedData", "NetworkReceivedData_" .. Mod:ID(), function(sender, messageType, data)

	if messageType == CustomWaypoints.Network.PlaceWaypoint then
		CustomWaypoints:NetworkPlace(sender, data)
	end

	if messageType == CustomWaypoints.Network.RemoveWaypoint then
		CustomWaypoints:NetworkRemove(sender)
	end

end)
-- END OF FILE
