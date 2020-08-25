--[[
                           _   _     __    ___    _____                             __  
                          (_) | |   /_ |  / _ \  | ____|                           / /
   ___   ___   _ __ ___    _  | |_   | | | (_) | | |__         _ __ ___   ___     / /
  / __| / __| | '_ ` _ \  | | | __|  | |  \__, | |___ \       | '_ ` _ \ / _ \   / /  
 | (__  \__ \ | | | | | | | | | |_   | |    / /   ___) |  _   | | | | | |  __/  / /  
  \___| |___/ |_| |_| |_| |_|  \__|  |_|   /_/   |____/  (_)  |_| |_| |_|\___| /_/    
   
   
    Script Name: Private $CP Script
    Script Author: csmit195
    Script Version: 1.0
    Script Description: Don't even fucking ask.
]]
local js = panorama.open()
local CompetitiveMatchAPI = js.CompetitiveMatchAPI
local GameStateAPI = js.GameStateAPI
local FriendsListAPI = js.FriendsListAPI

local CPPanorama = panorama.loadstring([[
	LocalSteamID = MyPersonaAPI.GetXuid();

	if ( typeof cp_DelayAutoAccept == 'undefined' ) {
		cp_DelayAutoAccept = {};
		cp_DelayAutoAccept.status = false;
		cp_DelayAutoAccept.delaySeconds = 15;
		
		cp_DelayAutoAccept.DelayAcceptFunc = ()=>{
			$.Schedule(cp_DelayAutoAccept.delaySeconds, function() {
				LobbyAPI.SetLocalPlayerReady('accept');
			});
		};
	}
	
	if ( typeof cp_AutoCSGOStats == 'undefined' ) {
		cp_AutoCSGOStats = {};
		cp_AutoCSGOStats.QueueConnectToServer = ()=>{
			$.Msg('When?!');
			
			SteamOverlayAPI.OpenExternalBrowserURL(`https://csgostats.gg/player/${LocalSteamID}#/live`);
		};
	}
	
	return {
		cp_DelayAutoAccept: {
			toggle: (status)=>{
				if ( status ) {
					cp_DelayAutoAccept.handle = $.RegisterForUnhandledEvent( 'PanoramaComponent_Lobby_ReadyUpForMatch', cp_DelayAutoAccept.DelayAcceptFunc);
					$.Msg('[$CP] registered for DelayAutoAccept');
				} else {
					if ( cp_DelayAutoAccept.handle ) {
						$.UnregisterForUnhandledEvent( 'PanoramaComponent_Lobby_ReadyUpForMatch', cp_DelayAutoAccept.handle);
						$.Msg('[$CP] Unregistered for DelayAutoAccept');
					}
				}
			},
			updateDelay: (delay)=>{
				cp_DelayAutoAccept.delaySeconds = delay;
				$.Msg('[$CP] updated delay to: ' + delay);
			}
		},
		cp_AutoCSGOStats: {
			toggle: (status)=>{
				if ( status ) {
					cp_AutoCSGOStats.handle = $.RegisterForUnhandledEvent( 'QueueConnectToServer', cp_AutoCSGOStats.QueueConnectToServer);
					$.Msg('[$CP] registered for AutoCSGOStats');
				} else {
					if ( cp_AutoCSGOStats.handle ) {
						$.UnregisterForUnhandledEvent( 'QueueConnectToServer', cp_AutoCSGOStats.handle);
						$.Msg('[$CP] Unregistered for AutoCSGOStats');
					}
				}
			}
		}
	}
]])();

local CPLua = {
	loops = {}
} 
CPLua.Header = ui.new_label('Lua', 'B', '=--------------  [   $CP Start   ]  --------------=')

-- START LegitResolver
CPLua.LegitResolver = {}
CPLua.LegitResolver.enable = ui.new_checkbox('Lua', 'B', 'Legit AA Resolver')
CPLua.LegitResolver.hotkey = ui.new_hotkey('Lua', 'B', 'Legit AA Resolver', true)

ui.set_callback(CPLua.LegitResolver.enable, function(self)
	local Status = ui.get(self)
	print(Status)
end)
-- END LegitResolver

-- START AutoAccept
CPLua.AutoAccept = {}
CPLua.AutoAccept.originalAutoAccept = ui.reference('MISC', 'Miscellaneous', 'Auto-accept matchmaking')
CPLua.AutoAccept.enable = ui.new_checkbox('Lua', 'B', 'Auto Accept Match')
CPLua.AutoAccept.delay = ui.new_slider('Lua', 'B', 'Auto Accept Delay', 1, 21, 3, true, 's')

ui.set_visible(CPLua.AutoAccept.delay, false)
CPPanorama.cp_DelayAutoAccept.toggle(false);

ui.set_callback(CPLua.AutoAccept.enable, function(self)
	local Status = ui.get(self)
	ui.set_visible(CPLua.AutoAccept.delay, Status)
	CPPanorama.cp_DelayAutoAccept.toggle(Status)
	
	if ( Status ) then
		ui.set(CPLua.AutoAccept.originalAutoAccept, not Status)
	end
end)
ui.set_callback(CPLua.AutoAccept.delay, function(self)
	CPPanorama.cp_DelayAutoAccept.updateDelay(ui.get(self))
end)
ui.set_callback(CPLua.AutoAccept.originalAutoAccept, function(self)
	if ( ui.get(self) ) then
		ui.set(CPLua.AutoAccept.enable, false)
	end
end)
-- END AutoAccept


-- START DerankScore
CPLua.DerankScore = {}
CPLua.DerankScore.enable = ui.new_checkbox('Lua', 'B', 'Auto Derank')
CPLua.DerankScore.method = ui.new_multiselect('Lua', 'B', 'Method', {'Round Start', 'During Timeout'})

ui.set_visible(CPLua.DerankScore.method, false)

ui.set_callback(CPLua.DerankScore.enable, function(self)
	local Status = ui.get(self)
	ui.set_visible(CPLua.DerankScore.method, Status)
end)

function CPLua.DerankScore.MethodState(Method)
	local Found = false
	for index, value in ipairs(ui.get(CPLua.DerankScore.method)) do
		if ( value == Method ) then
			Found = true
			break
		end
	end
	return Found
end

function CPLua.DerankScore.Reconnect()
	if CompetitiveMatchAPI.HasOngoingMatch() then
		print('reconnecting')
		return CompetitiveMatchAPI.ActionReconnectToOngoingMatch( '', '', '', '' ), derankcheck
	end
end

client.set_event_callback("round_freeze_end", function()
	if ui.get(CPLua.DerankScore.enable) and CPLua.DerankScore.MethodState('Round Start') then
		print('Trying the disconnect')
		client.delay_call(0, client.exec, "disconnect")
		client.delay_call(1, function()
			CPLua.DerankScore.Reconnect()
		end)
	end
end)

CPLua.DerankScore.Deranking = false
CPLua.loops[#CPLua.loops + 1] = function()
	if not CPLua.DerankScore.Deranking and ui.get(CPLua.DerankScore.enable) and CPLua.DerankScore.MethodState('During Timeout') and FriendsListAPI.IsGamePaused() and entity.is_alive(entity.get_local_player()) then
		local Team = (entity.get_prop(entity.get_game_rules(), "m_bCTTimeOutActive") == 1 and 'CT' or false) or (entity.get_prop(entity.get_game_rules(), "m_bTerroristTimeOutActive") == 1 and 'T' or false)
		local TimeoutRemaining = 0
		if ( Team == 'CT' ) then
			TimeoutRemaining = entity.get_prop(entity.get_game_rules(), "m_flCTTimeOutRemaining")
		elseif ( Team == 'T' ) then
			TimeoutRemaining = entity.get_prop(entity.get_game_rules(), "m_flTerroristTimeOutRemaining")
		end

		if ( TimeoutRemaining > 0) then
			CPLua.DerankScore.Deranking = true
			client.delay_call(0, client.exec, "disconnect")
			client.delay_call(1, function()
				CPLua.DerankScore.Reconnect()
			end)
		end
	end
end
client.set_event_callback('player_connect_full', function(e)
	print('someone connected')
	if ( entity.get_local_player() == client.userid_to_entindex(e.userid) ) then
		CPLua.DerankScore.Deranking = false
		print('derank false')
	end
end)
-- END DerankScore

-- START AutoCSGOStats
CPLua.AutoCSGOStats = {}
CPLua.AutoCSGOStats.enable = ui.new_checkbox('Lua', 'B', 'Auto CSGOStats')

CPPanorama.cp_AutoCSGOStats.toggle(false);

ui.set_callback(CPLua.AutoCSGOStats.enable, function(self)
	local Status = ui.get(self)
	CPPanorama.cp_AutoCSGOStats.toggle(Status)
end)
-- END AutoCSGOStats

-- START CustomClanTag
CPLua.Clantag = {}
CPLua.Clantag.last = ''
CPLua.Clantag.enable = ui.new_checkbox('Lua', 'B', 'Clantag')

-- END CustomClanTag

CPLua.Footer = ui.new_label('Lua', 'B', '=-------------  [   $CP Finish   ]  -------------=')

-- START DrawLoops
client.set_event_callback('paint', function()
	for index, func in ipairs(CPLua.loops) do
		func()
	end
end)
-- END DrawLoops

--[[ Clantag Logic
client.set_event_callback('paint', function()
	local Enabled = ui.get(CPLua.Clantag.enable)

	if ( Enabled ) then		
		local newClantag = 
		if ( CPLua.Clantag.last ~= newClantag ) then
			client.set_clan_tag(newClantag)
			CPLua.Clantag.last = newClantag
		end
	else
		if ( CPLua.Clantag.last ~= '' ) then
			client.set_clan_tag('')
			CPLua.Clantag.last = ''
			print('changed to empty')
		end
	end
end)
]]

--[[local LocalPlayer = entity.get_local_player()

client.set_event_callback('player_footstep', function(e)
	local UserEntity = client.userid_to_entindex(e.userid)
	
	if ( UserEntity == LocalPlayer ) then
		local PlayerName = entity.get_player_name(UserEntity)
		
		-- SetEntProp(client, Prop_Data, "m_fFlags", 4);
		--entity.set_prop(UserEntity, 'm_fFlags', 4)
		
		local flags = entity.get_prop( UserEntity, "m_fFlags" )
		
		if ( flags ) then
			print(flags)
		end
	end
end)
]]