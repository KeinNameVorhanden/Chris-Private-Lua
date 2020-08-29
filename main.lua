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

local csgo_weapons_success, csgo_weapons = pcall(require, 'gamesense/csgo_weapons')

-- Options
local Options = {
	debugMode = false
}

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
		},
		cp_PlaySound: (sound, type)=>{
			$.DispatchEvent( 'PlaySoundEffect', sound, type);
		},
		steamID: LocalSteamID
	}
]])();

-- adding into an init function just so I can better organise dependencies from other lib's at the bottom, until i work on a custom require lib from github.
function Initiate()
	-- [[ LUA TAB ]]
	local CPLua = {
		loops = {}
	} 
	CPLua.Header = ui.new_label('Lua', 'B', '=--------------  [   $CP Start   ]  --------------=')

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
			printDebug('reconnecting')
			return CompetitiveMatchAPI.ActionReconnectToOngoingMatch( '', '', '', '' ), derankcheck
		end
	end

	client.set_event_callback("round_freeze_end", function()
		if ui.get(CPLua.DerankScore.enable) and CPLua.DerankScore.MethodState('Round Start') then
			printDebug('Trying the disconnect')
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
		printDebug('someone connected')
		if ( entity.get_local_player() == client.userid_to_entindex(e.userid) ) then
			CPLua.DerankScore.Deranking = false
			printDebug('derank false')
		end
	end)
	-- END DerankScore

	-- START AutoCSGOStats
	CPLua.AutoCSGOStats = {}
	CPLua.AutoCSGOStats.enable = ui.new_checkbox('Lua', 'B', 'Auto CSGOStats.gg')

	CPPanorama.cp_AutoCSGOStats.toggle(false);

	ui.set_callback(CPLua.AutoCSGOStats.enable, function(self)
		local Status = ui.get(self)
		CPPanorama.cp_AutoCSGOStats.toggle(Status)
	end)
	-- END AutoCSGOStats

	-- START MatchStartBeep cp_PlaySound('popup_accept_match_beep', 'MOUSE')
	CPLua.MatchStartBeep = {}
	CPLua.MatchStartBeep.enable = ui.new_checkbox('Lua', 'B', 'Match Start Beep')
	CPLua.MatchStartBeep.repeatTimes = ui.new_slider('Lua', 'B', 'Times (x)', 1, 30, 1)
	CPLua.MatchStartBeep.repeatInterval = ui.new_slider('Lua', 'B', 'Interval (ms)', 0, 1000, 250, true, 'ms')
	CPLua.MatchStartBeep.delay = ui.new_slider('Lua', 'B', '% of Match Freezetime', 0, 100, 75, true, '%')

	CPLua.MatchStartBeep.sounds = {
		{'popup_accept_match_beep', 'Default (Beep)'},
		{'UIPanorama.generic_button_press', 'Generic Button'},
		{'mainmenu_press_home', 'Home Button'},
		{'tab_mainmenu_inventory', 'Inventory Tab'},
		{'tab_settings_settings', 'Settings Tab'},
		{'UIPanorama.mainmenu_press_quit', 'Quit Button'},
		{'sticker_applySticker', 'Sticker Apply'},
		{'sticker_nextPosition', 'Sticker Next Position'},
		{'container_sticker_ticker', 'Container Sticker Ticker'},
		{'container_weapon_ticker', 'Container Weapon Ticker'},
		{'container_countdown', 'Container Countdown'},
		{'inventory_inspect_sellOnMarket', 'Sell on Market'},
		{'UIPanorama.sidemenu_select', 'Sidemenu Select'},
		{'inventory_item_popupSelect', 'Item Popup'},
		{'UIPanorama.stats_reveal', 'Stats Reveal'},
		{'ItemRevealSingleLocalPlayer', 'Reveal Singleplayer'},
		{'ItemDropCommon', 'Item Drop (Common)'},
		{'ItemDropUncommon', 'Item Drop (Uncommon)'},
		{'ItemDropMythical', 'Item Drop (Mythical)'},
		{'ItemDropLegendary', 'Item Drop (Legendary)'},
		{'ItemDropAncient', 'Item Drop (Ancient)'},
		{'UIPanorama.XP.Ticker', 'XP Ticker'},
		{'UIPanorama.XP.BarFull', 'XP Bar Full'},
		{'UIPanorama.XP.NewRank', 'XP New Rank'},
		{'UIPanorama.XP.NewSkillGroup', 'New Skill Group'},
		{'UIPanorama.submenu_leveloptions_slidein', 'Map Vote SlideIn'},
		{'UIPanorama.submenu_leveloptions_select', 'Map Vote Select'},
		{'mainmenu_press_GO', 'Matchmaking Search'},
		{'buymenu_select', 'Buy Select'},
		{'UIPanorama.gameover_show', 'Gameover'},
		{'PanoramaUI.Lobby.Joined', 'Lobby Joined'},
		{'PanoramaUI.Lobby.Left', 'Lobby Left'},
		{'inventory_item_select', 'Inventory Select'},
		{'UIPanorama.inventory_new_item_accept', 'Inventory New Item'},
		{'sidemenu_slidein', 'Sidemenu Slidein'},
		{'sidemenu_slideout', 'Sidemenu Slideout'},
		{'UIPanorama.inventory_new_item', 'Inventory New Item'},
		{'inventory_inspect_weapon', 'Inventory Inspect Weapon'},
		{'inventory_inspect_knife', 'Inventory Inspect Knife'},
		{'inventory_inspect_sticker', 'Inventory Inspect Sticker'},
		{'inventory_inspect_graffiti', 'Inventory Inspect Graffiti'},
		{'inventory_inspect_musicKit', 'Inventory Inspect Music Kit'},
		{'inventory_inspect_coin', 'Inventory Inspect Coin'},
		{'inventory_inspect_gloves', 'Inventory Inspect Gloves'},
		{'inventory_inspect_close', 'Inventory Inspect Close'},
		{'popup_accept_match_waitquiet', 'Match Accept Tick'},
		{'popup_accept_match_person', 'Match Accept Person'},
		{'popup_accept_match_confirmed', 'Match Confirmed'},
		{'XrayStart', 'XRay Start'},
		{'rename_purchaseSuccess', 'Nametag Success'},
		{'rename_select', 'Nametag Select'},
 		{'rename_teletype', 'Nametag Teletype'},
		{'weapon_selectReplace', 'Weapon Select Replace'},
		{'UIPanorama.popup_newweapon', 'New Weapon Popup'}
	}
	local ProcessedSounds = {}
	local ReferenceSounds = {}
	for index, Sound in pairs(CPLua.MatchStartBeep.sounds) do
		ProcessedSounds[#ProcessedSounds + 1] = Sound[2]
		ReferenceSounds[Sound[2]] = Sound[1]
	end	
	CPLua.MatchStartBeep.sounds = ui.new_listbox('Lua', 'B', 'Sounds', ProcessedSounds)
	CPLua.MatchStartBeep.testsound = ui.new_button('Lua', 'B', 'Test Sound', function()
		local SelectedSound = ProcessedSounds[ui.get(CPLua.MatchStartBeep.sounds)+1]
		print(SelectedSound, '>', ReferenceSounds[SelectedSound])
		if ( SelectedSound and SelectedSound ~= '' and ReferenceSounds[SelectedSound] ) then
			CPPanorama.cp_PlaySound(ReferenceSounds[SelectedSound], 'MOUSE')
		end
	end)

	ui.set_visible(CPLua.MatchStartBeep.delay, false)
	ui.set_visible(CPLua.MatchStartBeep.sounds, false)
	ui.set_visible(CPLua.MatchStartBeep.testsound, false)

	ui.set_visible(CPLua.MatchStartBeep.repeatTimes, false)
	ui.set_visible(CPLua.MatchStartBeep.repeatInterval, false)

	ui.set_callback(CPLua.MatchStartBeep.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CPLua.MatchStartBeep.delay, Status)
		ui.set_visible(CPLua.MatchStartBeep.sounds, Status)
		ui.set_visible(CPLua.MatchStartBeep.testsound, Status)

		ui.set_visible(CPLua.MatchStartBeep.repeatTimes, Status)
		ui.set_visible(CPLua.MatchStartBeep.repeatInterval, ui.get(CPLua.MatchStartBeep.repeatTimes) ~= 1 and Status)
	end)

	ui.set_callback(CPLua.MatchStartBeep.repeatTimes, function(self)
		local Status = ui.get(self)
		ui.set_visible(CPLua.MatchStartBeep.repeatInterval, Status ~= 1)
	end)

	client.set_event_callback('round_start', function()
		if ( ui.get(CPLua.MatchStartBeep.enable) ) then
			local mp_freezetime = cvar.mp_freezetime:get_int()
			local percent = ui.get(CPLua.MatchStartBeep.delay) / 100
			client.delay_call(mp_freezetime * percent, function()
				local SelectedSound = ProcessedSounds[ui.get(CPLua.MatchStartBeep.sounds)+1] or 'Default (Beep)'
				if ( SelectedSound and SelectedSound ~= '' and ReferenceSounds[SelectedSound] ) then
					local Times = ui.get(CPLua.MatchStartBeep.repeatTimes)
					local Interval = ui.get(CPLua.MatchStartBeep.repeatInterval)
					if ( Times == 1 ) then
						CPPanorama.cp_PlaySound(ReferenceSounds[SelectedSound], 'MOUSE')
					else
						for i=1, Times do
							client.delay_call(Times == 1 and 0 or ( ( i - 1 ) * Interval ) / 1000, function()
								print('done')
								CPPanorama.cp_PlaySound(ReferenceSounds[SelectedSound], 'MOUSE')
							end)
						end
					end
				end
			end)
		end
	end)
	-- END MatchStartBeep

	-- START CustomClanTag
	CPLua.Clantag = {}
	CPLua.Clantag.last = ''
	CPLua.Clantag.enable = ui.new_checkbox('Lua', 'B', 'Clantag Builder [BETA]')
	CPLua.Clantag.template = ui.new_textbox('Lua', 'B', ' ')

	CPLua.Clantag.processedData = {}

	CPLua.Clantag.ranks = {
		'',
		'S1',
		'S2',
		'S3',
		'S4',
		'SE',
		'SEM',
		'GN1',
		'GN2',
		'GN3',
		'GNM',
		'MG1',
		'MG2',
		'MGE',
		'DMG',
		'LE',
		'LEM',
		'SMFC',
		'GE'
	}

	-- format {tag, refreshrate, updatefunc}
	CPLua.Clantag.data = {
		{'rank', 300, function()
			local Rank = entity.get_prop(entity.get_player_resource(), 'm_iCompetitiveRanking', entity.get_local_player())
			printDebug('RANK', Rank, CPLua.Clantag.ranks[Rank+1])
			if ( Rank ) then
				return CPLua.Clantag.ranks[Rank+1]
			end
		end, 0},
		{'wins', 300, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iCompetitiveWins', entity.get_local_player()) or ''
		end, 0},
		{'hp', 0.5, function()
			return entity.get_prop(entity.get_local_player(), 'm_iHealth') or 0
		end, 0},
		{'amr', 0.5, function()
			return entity.get_prop(entity.get_local_player(), 'm_ArmorValue') or 0
		end, 0},
		{'loc', 0.5, function()
			return entity.get_prop(entity.get_local_player(), 'm_szLastPlaceName') or ''
		end, 0},
		{'kills', 1, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iKills', entity.get_local_player()) or 0
		end, 0},
		{'deaths', 1, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iDeaths', entity.get_local_player()) or 0
		end, 0},
		{'assists', 1, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iAssists', entity.get_local_player()) or 0
		end, 0},
		{'headchance', 1, function()
			local LocalPlayer = entity.get_local_player()
			local TotalKills = CPLua.Clantag.processedData.kills
			local HeadshotKills = entity.get_prop(entity.get_player_resource(), 'm_iMatchStats_HeadShotKills_Total', entity.get_local_player())
			if ( TotalKills and HeadshotKills ) then				
				return math.ceil( (HeadshotKills / TotalKills) * 100 )
			end
		end, 0},
		{'c4', 1, function()
			-- Print C4 if has c4
		end, 0},
		{'wep', 0.25, function()
			if ( not csgo_weapons_success ) then return end

			local LocalPlayer = entity.get_local_player()

			local WeaponENT = entity.get_player_weapon(LocalPlayer)
			if WeaponENT == nil then return end

			local WeaponIDX = entity.get_prop(WeaponENT, "m_iItemDefinitionIndex")
			if WeaponIDX == nil then return end

			local weapon = csgo_weapons[WeaponIDX]
			if weapon == nil then return end
			
			return weapon.name
		end, 0},
		{'amo', 0.25, function()
			local LocalPlayer = entity.get_local_player()

			local WeaponENT = entity.get_player_weapon(LocalPlayer)
			if WeaponENT == nil then return end
			
			local Ammo = entity.get_prop(WeaponENT, "m_iClip1")
			if Ammo == nil then return end
			
			return Ammo
		end, 0},
		{'id', 9999, function()
			return CPPanorama.steamID
		end, 0},
		{'bomb', 1, function()
			local c4 = entity.get_all("CPlantedC4")[1]
			if c4 == nil or entity.get_prop(c4, "m_bBombDefused") == 1 or entity.get_local_player() == nil then return '' end
			local c4_time = entity.get_prop(c4, "m_flC4Blow") - globals.curtime()
   			return c4_time ~= nil and c4_time > 0 and math.floor(c4_time) or ''
		end, 0},
		{'doa', 0.5, function()
			return entity.is_alive(entity.get_local_player()) and 'ALIVE' or 'DEAD'
		end, 0},
		{'fps', 0.5, function()
			return AccumulateFps()
		end, 0},
		{'ping', 0.5, function()
			return math.floor(client.latency()*1000)
		end, 0}
	}
	
	ui.set_visible(CPLua.Clantag.template, false)

	ui.set_callback(CPLua.Clantag.enable, function(self)
		local Status = ui.get(self)
		client.set_clan_tag('')
		ui.set_visible(CPLua.Clantag.template, Status)
	end)

	CPLua.loops[#CPLua.loops + 1] = function()
		if ( not ui.get(CPLua.Clantag.enable) ) then return end

		-- DATA CALCULATIONS
		for index, value in ipairs(CPLua.Clantag.data) do
			local tag = value[1]
			local delay = value[2]
			local callfunc = value[3]
			
			if ( globals.curtime() > value[4] ) then
				local Output = callfunc()
				if ( Output == nil ) then
					CPLua.Clantag.processedData[tag] = ''
				elseif ( Output ) then
					CPLua.Clantag.processedData[tag] = Output
				end
				value[4] = globals.curtime() + delay
			end
		end
		local newClantag = processTags(ui.get(CPLua.Clantag.template), CPLua.Clantag.processedData)
		if ( CPLua.Clantag.last ~= newClantag ) then
			client.set_clan_tag(newClantag)
			CPLua.Clantag.last = newClantag
		end
	end

	client.set_event_callback('player_connect_full', function()
		CPLua.Clantag.last = ''
		for index, value in ipairs(CPLua.Clantag.data) do
			value[4] = 0
		end
	end)
	client.set_event_callback('round_start', function()
		CPLua.Clantag.last = ''
	end)
	-- END CustomClanTag

	-- START ReportTool
	CPLua.ReportTool = {}
	CPLua.ReportTool.enable = ui.new_checkbox('Lua', 'B', 'Report Tool')
	
	local ReportTypes = {
		{'textabuse', 'Comms Abuse'},
		{'voiceabuse', 'Voice Abuse'},
		{'grief', 'Griefing'},
		{'aimbot', 'Aim Hacking'},
		{'wallhack', 'Wall Hacking'},
		{'speedhack', 'Other Hacking'}
	}
	local ReportTypeNames = {}
	local ReportTypeRef = {}
	for index, ReportType in ipairs(ReportTypes) do
		ReportTypeNames[#ReportTypeNames + 1] = ReportType[2]
		ReportTypeRef[ReportType[2]] = ReportType[1]
	end
	CPLua.ReportTool.types = ui.new_multiselect('Lua', 'B', 'Types', ReportTypeNames)
	CPLua.ReportTool.submit = ui.new_button('Lua', 'B', 'Report!', function()
		local Types = ui.get(CPLua.ReportTool.types)
		local ReportTypes = ''
		for i, v in pairs(Types) do
			ReportTypes = ( i == 1 and ReportTypeRef[v] or ReportTypes..','..ReportTypeRef[v] )
		end

		local ReportQueue = {}
		for Player=1, globals.maxplayers() do
			local SteamXUID = GameStateAPI.GetPlayerXuidStringFromEntIndex(Player)
			if ( SteamXUID:len() > 5 and entity.is_enemy(Player) ) then
				ReportQueue[#ReportQueue + 1] = SteamXUID
			end
		end

		-- Actual Reporting
		for index, Reportee in ipairs(ReportQueue) do
			client.delay_call((index - 1) * 1, function()
				GameStateAPI.SubmitPlayerReport(Reportee, ReportTypes)
			end)
		end
	end)
	


	ui.set_callback(CPLua.ReportTool.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CPLua.ReportTool.types, Status)
		ui.set_visible(CPLua.ReportTool.submit, Status)
	end)
	ui.set_visible(CPLua.ReportTool.types, false)
	ui.set_visible(CPLua.ReportTool.submit, false)
	-- END ReportTool

	-- START DebugOptions
	CPLua.DebugOptions = {}
	CPLua.DebugOptions.enable = ui.new_checkbox('Lua', 'B', 'Debug Mode (console)')
	ui.set_callback(CPLua.DebugOptions.enable, function(self)
		local Status = ui.get(self)
		Options.debugMode = Status
	end)
	-- END DebugOptions

	CPLua.Footer = ui.new_label('Lua', 'B', '=-------------  [   $CP Finish   ]  -------------=')

	-- START DrawLoops
	client.set_event_callback('paint', function()
		for index, func in ipairs(CPLua.loops) do
			func()
		end
	end)
	-- END DrawLoops

	-- [[ PLAYER TAB ]]
	local style = {
		letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' ",
		trans = {
			bold = {"𝗮","𝗯","𝗰","𝗱","𝗲","𝗳","𝗴","𝗵","𝗶","𝗷","𝗸","𝗹","𝗺","𝗻","𝗼","𝗽","𝗾","𝗿","𝘀","𝘁","𝘂","𝘃","𝘄","𝘅","𝘆","𝘇","𝗔","𝗕","𝗖","𝗗","𝗘","𝗙","𝗚","𝗛","𝗜","𝗝","𝗞","𝗟","𝗠","𝗡","𝗢","𝗣","𝗤","𝗥","𝗦","𝗧","𝗨","𝗩","𝗪","𝗫","𝗬","𝗭","𝟬","𝟭","𝟮","𝟯","𝟰","𝟱","𝟲","𝟳","𝟴","𝟵","'"," "},
			bolditalic = {"𝙖","𝙗","𝙘","𝙙","𝙚","𝙛","𝙜","𝙝","𝙞","𝙟","𝙠","𝙡","𝙢","𝙣","𝙤","𝙥","𝙦","𝙧","𝙨","𝙩","𝙪","𝙫","𝙬","𝙭","𝙮","𝙯", "𝘼","𝘽","𝘾","𝘿","𝙀","𝙁","𝙂","𝙃","𝙄","𝙅","𝙆","𝙇","𝙈","𝙉","𝙊","𝙋","𝙌","𝙍","𝙎","𝙏","𝙐","𝙑","𝙒","𝙓","𝙔","𝙕", "0","1","2","3","4","5","6","7","8","9","'"," "},
			italic = {"𝘢","𝘣","𝘤","𝘥","𝘦","𝘧","𝘨","𝘩","𝘪","𝘫","𝘬","𝘭","𝘮","𝘯","𝘰","𝘱","𝘲","𝘳","𝘴","𝘵","𝘶","𝘷","𝘸","𝘹","𝘺","𝘻", "𝘈","𝘉","𝘊","𝘋","𝘌","𝘍","𝘎","𝘏","𝘐","𝘑","𝘒","𝘓","𝘔","𝘕","𝘖","𝘗","𝘘","𝘙","𝘚","𝘛","𝘜","𝘝","𝘞","𝘟","𝘠","𝘡", "0","1","2","3","4","5","6","7","8","9","'"," "},
			circled = {"ⓐ","ⓑ","ⓒ","ⓓ","ⓔ","ⓕ","ⓖ","ⓗ","ⓘ","ⓙ","ⓚ","ⓛ","ⓜ","ⓝ","ⓞ","ⓟ","ⓠ","ⓡ","ⓢ","ⓣ","ⓤ","ⓥ","ⓦ","ⓧ","ⓨ","ⓩ", "Ⓐ","Ⓑ","Ⓒ","Ⓓ","Ⓔ","Ⓕ","Ⓖ","Ⓗ","Ⓘ","Ⓙ","Ⓚ","Ⓛ","Ⓜ","Ⓝ","Ⓞ","Ⓟ","Ⓠ","Ⓡ","Ⓢ","Ⓣ","Ⓤ","Ⓥ","Ⓦ","Ⓧ","Ⓨ","Ⓩ", "0","①","②","③","④","⑤","⑥","⑦","⑧","⑨","'"," "},
			circledNeg = {"🅐","🅑","🅒","🅓","🅔","🅕","🅖","🅗","🅘","🅙","🅚","🅛","🅜","🅝","🅞","🅟","🅠","🅡","🅢","🅣","🅤","🅥","🅦","🅧","🅨","🅩", "🅐","🅑","🅒","🅓","🅔","🅕","🅖","🅗","🅘","🅙","🅚","🅛","🅜","🅝","🅞","🅟","🅠","🅡","🅢","🅣","🅤","🅥","🅦","🅧","🅨","🅩", "⓿","1","2","3","4","5","6","7","8","9","'"," "},
			fullwidth = {"ａ","ｂ","ｃ","ｄ","ｅ","ｆ","ｇ","ｈ","ｉ","ｊ","ｋ","ｌ","ｍ","ｎ","ｏ","ｐ","ｑ","ｒ","ｓ","ｔ","ｕ","ｖ","ｗ","ｘ","ｙ","ｚ", "Ａ","Ｂ","Ｃ","Ｄ","Ｅ","Ｆ","Ｇ","Ｈ","Ｉ","Ｊ","Ｋ","Ｌ","Ｍ","Ｎ","Ｏ","Ｐ","Ｑ","Ｒ","Ｓ","Ｔ","Ｕ","Ｖ","Ｗ","Ｘ","Ｙ","Ｚ", "０","１","２","３","４","５","６","７","８","９","＇","　"},
			fraktur = {"𝔞","𝔟","𝔠","𝔡","𝔢","𝔣","𝔤","𝔥","𝔦","𝔧","𝔨","𝔩","𝔪","𝔫","𝔬","𝔭","𝔮","𝔯","𝔰","𝔱","𝔲","𝔳","𝔴","𝔵","𝔶","𝔷", "𝔄","𝔅","ℭ","𝔇","𝔈","𝔉","𝔊","ℌ","ℑ","𝔍","𝔎","𝔏","𝔐","𝔑","𝔒","𝔓","𝔔","ℜ","𝔖","𝔗","𝔘","𝔙","𝔚","𝔛","𝔜","ℨ", "0","1","2","3","4","5","6","7","8","9","'"," "},
			frakturbold = {"𝖆","𝖇","𝖈","𝖉","𝖊","𝖋","𝖌","𝖍","𝖎","𝖏","𝖐","𝖑","𝖒","𝖓","𝖔","𝖕","𝖖","𝖗","𝖘","𝖙","𝖚","𝖛","𝖜","𝖝","𝖞","𝖟", "𝕬","𝕭","𝕮","𝕯","𝕰","𝕱","𝕲","𝕳","𝕴","𝕵","𝕶","𝕷","𝕸","𝕹","𝕺","𝕻","𝕼","𝕽","𝕾","𝕿","𝖀","𝖁","𝖂","𝖃","𝖄","𝖅", "0","1","2","3","4","5","6","7","8","9","'"," "},
			script = {"𝓪","𝓫","𝓬","𝓭","𝓮","𝓯","𝓰","𝓱","𝓲","𝓳","𝓴","𝓵","𝓶","𝓷","𝓸","𝓹","𝓺","𝓻","𝓼","𝓽","𝓾","𝓿","𝔀","𝔁","𝔂","𝔃", "𝓐","𝓑","𝓒","𝓓","𝓔","𝓕","𝓖","𝓗","𝓘","𝓙","𝓚","𝓛","𝓜","𝓝","𝓞","𝓟","𝓠","𝓡","𝓢","𝓣","𝓤","𝓥","𝓦","𝓧","𝓨","𝓩", "0","1","2","3","4","5","6","7","8","9","'"," "},
			doublestruck = {"𝕒","𝕓","𝕔","𝕕","𝕖","𝕗","𝕘","𝕙","𝕚","𝕛","𝕜","𝕝","𝕞","𝕟","𝕠","𝕡","𝕢","𝕣","𝕤","𝕥","𝕦","𝕧","𝕨","𝕩","𝕪","𝕫", "𝔸","𝔹","ℂ","𝔻","𝔼","𝔽","𝔾","ℍ","𝕀","𝕁","𝕂","𝕃","𝕄","ℕ","𝕆","ℙ","ℚ","ℝ","𝕊","𝕋","𝕌","𝕍","𝕎","𝕏","𝕐","ℤ", "𝟘","𝟙","𝟚","𝟛","𝟜","𝟝","𝟞","𝟟","𝟠","𝟡","'"," "},
			monospace = {"𝚊","𝚋","𝚌","𝚍","𝚎","𝚏","𝚐","𝚑","𝚒","𝚓","𝚔","𝚕","𝚖","𝚗","𝚘","𝚙","𝚚","𝚛","𝚜","𝚝","𝚞","𝚟","𝚠","𝚡","𝚢","𝚣", "𝙰","𝙱","𝙲","𝙳","𝙴","𝙵","𝙶","𝙷","𝙸","𝙹","𝙺","𝙻","𝙼","𝙽","𝙾","𝙿","𝚀","𝚁","𝚂","𝚃","𝚄","𝚅","𝚆","𝚇","𝚈","𝚉", "𝟶","𝟷","𝟸","𝟹","𝟺","𝟻","𝟼","𝟽","𝟾","𝟿","'"," "},
			parenthesized = {"⒜","⒝","⒞","⒟","⒠","⒡","⒢","⒣","⒤","⒥","⒦","⒧","⒨","⒩","⒪","⒫","⒬","⒭","⒮","⒯","⒰","⒱","⒲","⒳","⒴","⒵", "⒜","⒝","⒞","⒟","⒠","⒡","⒢","⒣","⒤","⒥","⒦","⒧","⒨","⒩","⒪","⒫","⒬","⒭","⒮","⒯","⒰","⒱","⒲","⒳","⒴","⒵", "0","⑴","⑵","⑶","⑷","⑸","⑹","⑺","⑻","⑼","'"," "},
			regional = {"🇦","🇧","🇨","🇩","🇪","🇫","🇬","🇭","🇮","🇯","🇰","🇱","🇲","🇳","🇴","🇵","🇶","🇷","🇸","🇹","🇺","🇻","🇼","🇽","🇾","🇿", "🇦","🇧","🇨","🇩","🇪","🇫","🇬","🇭","🇮","🇯","🇰","🇱","🇲","🇳","🇴","🇵","🇶","🇷","🇸","🇹","🇺","🇻","🇼","🇽","🇾","🇿", "0","1","2","3","4","5","6","7","8","9","'"," "},
			squared = {"🄰","🄱","🄲","🄳","🄴","🄵","🄶","🄷","🄸","🄹","🄺","🄻","🄼","🄽","🄾","🄿","🅀","🅁","🅂","🅃","🅄","🅅","🅆","🅇","🅈","🅉", "🄰","🄱","🄲","🄳","🄴","🄵","🄶","🄷","🄸","🄹","🄺","🄻","🄼","🄽","🄾","🄿","🅀","🅁","🅂","🅃","🅄","🅅","🅆","🅇","🅈","🅉", "0","1","2","3","4","5","6","7","8","9","'"," "},
			squaredNeg = {"🅰","🅱","🅲","🅳","🅴","🅵","🅶","🅷","🅸","🅹","🅺","🅻","🅼","🅽","🅾","🅿","🆀","🆁","🆂","🆃","🆄","🆅","🆆","🆇","🆈","🆉", "🅰","🅱","🅲","🅳","🅴","🅵","🅶","🅷","🅸","🅹","🅺","🅻","🅼","🅽","🅾","🅿","🆀","🆁","🆂","🆃","🆄","🆅","🆆","🆇","🆈","🆉", "0","1","2","3","4","5","6","7","8","9","'"," "},
			acute = {"á","b","ć","d","é","f","ǵ","h","í","j","ḱ","ĺ","ḿ","ń","ő","ṕ","q","ŕ","ś","t","ú","v","ẃ","x","ӳ","ź", "Á","B","Ć","D","É","F","Ǵ","H","í","J","Ḱ","Ĺ","Ḿ","Ń","Ő","Ṕ","Q","Ŕ","ś","T","Ű","V","Ẃ","X","Ӳ","Ź", "0","1","2","3","4","5","6","7","8","9","'"," "},
			thai = {"ﾑ","乃","c","d","乇","ｷ","g","ん","ﾉ","ﾌ","ズ","ﾚ","ﾶ","刀","o","ｱ","q","尺","丂","ｲ","u","√","w","ﾒ","ﾘ","乙", "ﾑ","乃","c","d","乇","ｷ","g","ん","ﾉ","ﾌ","ズ","ﾚ","ﾶ","刀","o","ｱ","q","尺","丂","ｲ","u","√","w","ﾒ","ﾘ","乙", "0","1","2","3","4","5","6","7","8","9","'"," "},
			curvy1 = {"ค","๒","ƈ","ɗ","ﻉ","ि","ﻭ","ɦ","ٱ","ﻝ","ᛕ","ɭ","๓","ก","ѻ","ρ","۹","ɼ","ร","Շ","પ","۷","ฝ","ซ","ץ","չ", "ค","๒","ƈ","ɗ","ﻉ","ि","ﻭ","ɦ","ٱ","ﻝ","ᛕ","ɭ","๓","ก","ѻ","ρ","۹","ɼ","ร","Շ","પ","۷","ฝ","ซ","ץ","չ", "0","1","2","3","4","5","6","7","8","9","'"," "},
			curvy2 = {"α","в","¢","∂","є","ƒ","ﻭ","н","ι","נ","к","ℓ","м","η","σ","ρ","۹","я","ѕ","т","υ","ν","ω","χ","у","չ", "α","в","¢","∂","є","ƒ","ﻭ","н","ι","נ","к","ℓ","м","η","σ","ρ","۹","я","ѕ","т","υ","ν","ω","χ","у","չ", "0","1","2","3","4","5","6","7","8","9","'"," "},
			curvy3 = {"ค","๒","ς","๔","є","Ŧ","ﻮ","ђ","เ","ן","к","ɭ","๓","ภ","๏","ק","ợ","г","ร","Շ","ย","ש","ฬ","א","ץ","չ", "ค","๒","ς","๔","є","Ŧ","ﻮ","ђ","เ","ן","к","ɭ","๓","ภ","๏","ק","ợ","г","ร","Շ","ย","ש","ฬ","א","ץ","չ", "0","1","2","3","4","5","6","7","8","9","'"," "},
			fauxcryllic = {"а","ъ","с","ↁ","э","f","Б","Ђ","і","ј","к","l","м","и","о","р","q","ѓ","ѕ","т","ц","v","ш","х","Ў","z", "Д","Б","Ҁ","ↁ","Є","F","Б","Н","І","Ј","Ќ","L","М","И","Ф","Р","Q","Я","Ѕ","Г","Ц","V","Щ","Ж","Ч","Z", "0","1","2","3","4","5","6","7","8","9","'"," "},
			rockdots = {"ä","ḅ","ċ","ḋ","ë","ḟ","ġ","ḧ","ï","j","ḳ","ḷ","ṁ","ṅ","ö","ṗ","q","ṛ","ṡ","ẗ","ü","ṿ","ẅ","ẍ","ÿ","ż", "Ä","Ḅ","Ċ","Ḋ","Ё","Ḟ","Ġ","Ḧ","Ї","J","Ḳ","Ḷ","Ṁ","Ṅ","Ö","Ṗ","Q","Ṛ","Ṡ","Ṫ","Ü","Ṿ","Ẅ","Ẍ","Ÿ","Ż", "0","1","2","ӟ","4","5","6","7","8","9","'"," "},
			smallcaps = {"ᴀ","ʙ","ᴄ","ᴅ","ᴇ","ꜰ","ɢ","ʜ","ɪ","ᴊ","ᴋ","ʟ","ᴍ","ɴ","ᴏ","ᴩ","q","ʀ","ꜱ","ᴛ","ᴜ","ᴠ","ᴡ","x","y","ᴢ", "ᴀ","ʙ","ᴄ","ᴅ","ᴇ","ꜰ","ɢ","ʜ","ɪ","ᴊ","ᴋ","ʟ","ᴍ","ɴ","ᴏ","ᴩ","Q","ʀ","ꜱ","ᴛ","ᴜ","ᴠ","ᴡ","x","Y","ᴢ", "0","1","2","3","4","5","6","7","8","9","'"," "},
			stroked = {"Ⱥ","ƀ","ȼ","đ","ɇ","f","ǥ","ħ","ɨ","ɉ","ꝁ","ł","m","n","ø","ᵽ","ꝗ","ɍ","s","ŧ","ᵾ","v","w","x","ɏ","ƶ", "Ⱥ","Ƀ","Ȼ","Đ","Ɇ","F","Ǥ","Ħ","Ɨ","Ɉ","Ꝁ","Ł","M","N","Ø","Ᵽ","Ꝗ","Ɍ","S","Ŧ","ᵾ","V","W","X","Ɏ","Ƶ", "0","1","ƻ","3","4","5","6","7","8","9","'"," "},
			subscript = {"ₐ","b","c","d","ₑ","f","g","ₕ","ᵢ","ⱼ","ₖ","ₗ","ₘ","ₙ","ₒ","ₚ","q","ᵣ","ₛ","ₜ","ᵤ","ᵥ","w","ₓ","y","z", "ₐ","B","C","D","ₑ","F","G","ₕ","ᵢ","ⱼ","ₖ","ₗ","ₘ","ₙ","ₒ","ₚ","Q","ᵣ","ₛ","ₜ","ᵤ","ᵥ","W","ₓ","Y","Z", "₀","₁","₂","₃","₄","₅","₆","₇","₈","₉","'"," "},
			superscript = {"ᵃ","ᵇ","ᶜ","ᵈ","ᵉ","ᶠ","ᵍ","ʰ","ⁱ","ʲ","ᵏ","ˡ","ᵐ","ⁿ","ᵒ","ᵖ","q","ʳ","ˢ","ᵗ","ᵘ","ᵛ","ʷ","ˣ","ʸ","ᶻ", "ᴬ","ᴮ","ᶜ","ᴰ","ᴱ","ᶠ","ᴳ","ᴴ","ᴵ","ᴶ","ᴷ","ᴸ","ᴹ","ᴺ","ᴼ","ᴾ","Q","ᴿ","ˢ","ᵀ","ᵁ","ⱽ","ᵂ","ˣ","ʸ","ᶻ", "⁰","¹","²","³","⁴","⁵","⁶","⁷","⁸","⁹","'"," "},
			inverted = {"ɐ","q","ɔ","p","ǝ","ɟ","ƃ","ɥ","ı","ɾ","ʞ","ן","ɯ","u","o","d","b","ɹ","s","ʇ","n","ʌ","ʍ","x","ʎ","z", "ɐ","q","ɔ","p","ǝ","ɟ","ƃ","ɥ","ı","ɾ","ʞ","ן","ɯ","u","o","d","b","ɹ","s","ʇ","n","𐌡","ʍ","x","ʎ","z", "0","1","2","3","4","5","6","7","8","9",","," "},
		}
	}

	function transText(types, text)
		if not style.trans[types] then return text end
		local output = ''
		for i=1, #text do
			local char = text:sub(i,i)
			output = output .. ( style.trans[types][style.letters:find(char)] or char )
		end
		return output
	end

	function changeCaseWord(str)
		local u = ""
		for i = 1, #str do
			if i % 2 == 1 then
				u = u .. string.upper(str:sub(i, i))
			else
				u = u .. string.lower(str:sub(i, i))
			end
		end
		return u
	end

	function changeCase(original)
		local words = {}
		for v in original:gmatch("%w+") do 
			words[#words + 1] = v
		end
		for i,v in ipairs(words) do
			words[i] = changeCaseWord(v)
		end
		return table.concat(words, " ")
	end

	-- UI References
	local PlayerList = ui.reference('Players', 'Players', 'Player list')
	local ResetAll = ui.reference('Players', 'Players', 'Reset all')
	local ApplyToAll = ui.reference('Players', 'Adjustments', 'Apply to all')

	-- Script UI
	local MessageRepeater = {}
	MessageRepeater.header = ui.new_label('Players', 'Adjustments', '=---------  [  $CP Adjustments  ]  ---------=')
	MessageRepeater.repeatMessages = ui.new_checkbox('Players', 'Adjustments', 'Repeat Messages')

	local RepeatMethods = {'Shift Case'}
	for i, v in pairs(style.trans) do
		RepeatMethods[#RepeatMethods + 1] = i
	end
	MessageRepeater.repeatMethod = ui.new_combobox('Players', 'Adjustments', 'Repeat Method', RepeatMethods)
	ui.set_visible(MessageRepeater.repeatMethod, false)

	MessageRepeater.cache = {}
	ui.set_callback(MessageRepeater.repeatMessages, function(self)
		local Status = ui.get(self)
		local Player = ui.get(PlayerList)
		
		if ( Player ) then
			ui.set_visible(MessageRepeater.repeatMethod, Status)
			
			if ( not MessageRepeater.cache[Player] ) then
				MessageRepeater.cache[Player] = {}
				MessageRepeater.cache[Player].Method = 'Shift Case'
			end
			
			MessageRepeater.cache[Player].Status = Status
			
			ui.set(MessageRepeater.repeatMethod, MessageRepeater.cache[Player].Method)
		end
	end)

	ui.set_callback(MessageRepeater.repeatMethod, function(self)
		local Method = ui.get(self)
		local Player = ui.get(PlayerList)
		
		if ( Player ) then
			MessageRepeater.cache[Player].Method = Method
		end
	end)

	ui.set_callback(PlayerList, function(self)
		local entindex = ui.get(self)
		
		if ( entindex ) then
			if ( MessageRepeater.cache[entindex] == nil ) then
				MessageRepeater.cache[entindex] = {}
				MessageRepeater.cache[entindex].Status = false
				MessageRepeater.cache[entindex].Method = 'Shift Case'
			end
			
			ui.set(MessageRepeater.repeatMessages, MessageRepeater.cache[entindex].Status)
			ui.set(MessageRepeater.repeatMethod, MessageRepeater.cache[entindex].Method)
		end
	end)

	ui.set_callback(ResetAll, function(self)
		MessageRepeater.cache = {}
		ui.set(MessageRepeater.repeatMessages, false)
	end)

	ui.set_callback(ApplyToAll, function(self)
		for Player=1, globals.maxplayers() do
			if ( entity.is_enemy(Player) ) then
				MessageRepeater.cache[Player] = {}
				MessageRepeater.cache[Player].Status = true
				MessageRepeater.cache[Player].Method = ui.get(MessageRepeater.repeatMethod)
			end
		end
	end)

	client.set_event_callback('player_chat', function (e)
		if ( not e.teamonly ) then
			local ent, name, text = e.entity, e.name, e.text
			if ( entity.is_enemy(ent) and MessageRepeater.cache[ent] ~= nil and MessageRepeater.cache[ent].Status and MessageRepeater.cache[ent].Method ) then
				local Method = MessageRepeater.cache[ent].Method
				local Message = text
				
				if ( Method == 'Shift Case' ) then
					Message = changeCase(text)
				else
					Message = transText(Method, text)
				end
				
				client.exec("say ", Message)
			end
		end
	end)

	client.set_event_callback('cs_win_panel_match', function(e)
		MessageRepeater.cache = {}
		ui.set(MessageRepeater.repeatMessages, false)
	end)
end

-- Utilities / Libraries
function processTags(str, vars)
	if not vars then
		vars = str
		str = vars[1]
	  end
	  return (string.gsub(str, "({([^}]+)})",
		function(whole,i)
		  return vars[i] or whole
		end))
end

function printDebug(...)
	if ( not Options.debugMode ) then return end
	printDebug(...)
end

local frametimes = {}
local fps_prev = 0
local last_update_time = 0
function AccumulateFps()
	local ft = globals.absoluteframetime()
	if ft > 0 then
		table.insert(frametimes, 1, ft)
	end
	local count = #frametimes
	if count == 0 then
		return 0
	end
	local i, accum = 0, 0
	while accum < 0.5 do
		i = i + 1
		accum = accum + frametimes[i]
		if i >= count then
			break
		end
	end
	accum = accum / i
	while i < count do
		i = i + 1
		table.remove(frametimes)
	end
	local fps = 1 / accum
	local rt = globals.realtime()
	if math.abs(fps - fps_prev) > 4 or rt - last_update_time > 2 then
		fps_prev = fps
		last_update_time = rt
	else
		fps = fps_prev
	end
	return math.ceil(fps + 0.5)
end

Initiate()