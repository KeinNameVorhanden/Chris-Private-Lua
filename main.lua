--[[
                           _   _     __    ___    _____                             __  
                          (_) | |   /_ |  / _ \  | ____|                           / /
   ___   ___   _ __ ___    _  | |_   | | | (_) | | |__         _ __ ___   ___     / / 
  / __| / __| | '_ ` _ \  | | | __|  | |  \__, | |___ \       | '_ ` _ \ / _ \   / /  
 | (__  \__ \ | | | | | | | | | |_   | |    / /   ___) |  _   | | | | | |  __/  / /   
  \___| |___/ |_| |_| |_| |_|  \__|  |_|   /_/   |____/  (_)  |_| |_| |_|\___| /_/    
   
   
    Script Name: Chris's Public Script (CS)
    Script Author: csmit195
    Script Version: 1.0
    Script Description: A soon to be public lua for all of man kind.
]]
local js = panorama.open()
local CompetitiveMatchAPI = js.CompetitiveMatchAPI
local GameStateAPI = js.GameStateAPI
local FriendsListAPI = js.FriendsListAPI
local PartyListAPI = js.PartyListAPI

local ffi = require("ffi")
local csgo_weapons = require('gamesense/csgo_weapons')
local http = require('gamesense/http')


-- Options
local Options = {
	debugMode = false
}

--#region Startup Panorama Code
local CSPanorama = panorama.loadstring([[
	LocalSteamID = MyPersonaAPI.GetXuid();

	if ( typeof CS_print == 'undefined' ) {
		CS_debugMode = false;
		CS_print = (args)=>{
			if ( CS_debugMode ) {
				$.Msg('[csmit195\'s Lua] ', args);
			}
		}
	}

	if ( typeof CS_SayPartyChat == 'undefined' ) {
		CS_SayPartyChat = (broadcast, msg)=>{
			let Message = msg.split(' ').join('\u{00A0}');
			let MySteamID = MyPersonaAPI.GetXuid();
			PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MySteamID} chat ${Message}`);
			PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MySteamID} chat ${Message}`);
		}
	}
	
	if ( typeof CS_DelayAutoAccept == 'undefined' ) {
		CS_DelayAutoAccept = {};
		CS_DelayAutoAccept.status = false;
		CS_DelayAutoAccept.delaySeconds = 15;
		
		CS_DelayAutoAccept.DelayAcceptFunc = ()=>{
			$.Schedule(CS_DelayAutoAccept.delaySeconds, function() {
				LobbyAPI.SetLocalPlayerReady('accept');
			});
		};
	}

	if ( typeof CS_AutoAcceptDetection == 'undefined' ) {
		CS_AutoAcceptDetection = {};
		CS_AutoAcceptDetection.status = false;
		CS_AutoAcceptDetection.last = 0;
		
		CS_AutoAcceptDetection.EventFunc = (shouldShow, playersReadyCount, numTotalClientsInReservation)=>{
			let PossibleAutoAccepts = playersReadyCount - CS_AutoAcceptDetection.last;
			CS_AutoAcceptDetection.last = playersReadyCount;
			if ( PossibleAutoAccepts > 2 ) {
				CS_print(`[$CS Detection Module] Possible ${PossibleAutoAccepts} Auto Accepts`);
			}
		};
	}
	
	if ( typeof CS_AutoCSGOStats == 'undefined' ) {
		CS_AutoCSGOStats = {};
		CS_AutoCSGOStats.QueueConnectToServer = ()=>{
			CS_print('Opening CSGOStats.gg in user browser');
			
			SteamOverlayAPI.OpenExternalBrowserURL(`https://csgostats.gg/player/${LocalSteamID}#/live`);
		};
	}
	
	if ( typeof CS_LongPollSubscribe == 'undefined' ) {
		let subscribe = function(url, cb) {
			$.AsyncWebRequest(url,
				{
					method:'GET',
					success:function(data) {
						cb(data)
					},
					complete:function(data){
						$.Schedule(1, function() {
							subscribe(url, cb);
						});
					},
					timeout: 30000
				}
			);
		};

		/*subscribe("http://localhost:1341/GlobalPoll", function (data) {
			$.Msg("Data:", data, typeof data);
		});*/

		CS_LongPollSubscribe = {};
	}

	return {
		CS_DelayAutoAccept: {
			toggle: (status)=>{
				if ( status ) {
					CS_DelayAutoAccept.handle = $.RegisterForUnhandledEvent( 'PanoramaComponent_Lobby_ReadyUpForMatch', CS_DelayAutoAccept.DelayAcceptFunc);
					CS_print('Registered for DelayAutoAccept');
				} else {
					if ( CS_DelayAutoAccept.handle ) {
						$.UnregisterForUnhandledEvent( 'PanoramaComponent_Lobby_ReadyUpForMatch', CS_DelayAutoAccept.handle);
						CS_print('Unregistered for DelayAutoAccept');
					}
				}
			},
			updateDelay: (delay)=>{
				CS_DelayAutoAccept.delaySeconds = delay;
				CS_print('Updated delay to: ' + delay);
			}
		},
		CS_AutoAcceptDetection: {
			toggle: (status)=>{
				if ( status && !CS_AutoAcceptDetection.handle ) {
					CS_AutoAcceptDetection.handle = $.RegisterForUnhandledEvent( 'PanoramaComponent_Lobby_ReadyUpForMatch', CS_AutoAcceptDetection.EventFunc);
					CS_print('Registered for CS_AutoAcceptDetection');
				} else {
					if ( CS_AutoAcceptDetection.handle ) {
						$.UnregisterForUnhandledEvent( 'PanoramaComponent_Lobby_ReadyUpForMatch', CS_AutoAcceptDetection.handle);
						CS_AutoAcceptDetection.handle = false;
						CS_print('Unregistered for CS_AutoAcceptDetection');
					}
				}
			}
		},
		CS_AutoCSGOStats: {
			toggle: (status)=>{
				if ( status && !CS_AutoCSGOStats.handle ) {
					CS_AutoCSGOStats.handle = $.RegisterForUnhandledEvent( 'QueueConnectToServer', CS_AutoCSGOStats.QueueConnectToServer);
					CS_print('Registered for AutoCSGOStats');
				} else {
					if ( CS_AutoCSGOStats.handle ) {
						$.UnregisterForUnhandledEvent( 'QueueConnectToServer', CS_AutoCSGOStats.handle);
						CS_AutoCSGOStats.handle = false;
						CS_print('Unregistered for AutoCSGOStats');
					}
				}
			}
		},
		CS_Localize: (...args)=>{
			return $.Localize.apply(null, args);
		},
		CS_PlaySound: (sound, type)=>{
			$.DispatchEvent( 'PlaySoundEffect', sound, type);
		},
		setDebugMode: (state)=>{
			CS_debugMode = state;
		},
		steamID: LocalSteamID
	}
]])();

CSPanoramaMainMenu = panorama.loadstring([[
	// Lobby Chat Utils
	let Prefix = '!';

	let PartyChatCommands = [];
	PartyChatCommands.push({
		title: 'Help (!\u{200B}help)',
		cmds: ['help', 'h'],
		exec: (cmd, args) => {
			if ( args.length == 0 ) {
				for ( i=1; i<PartyChatCommands.length; i++ ) {
					let ChatCommand = PartyChatCommands[i];
					const Title = `» ${ChatCommand.title}`;
					const Alias = ChatCommand.cmds;
					let Message = Title.split(' ').join('\u{00A0}');
					let MySteamID = MyPersonaAPI.GetXuid();
					PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MySteamID} chat ${Message}`);
				}
			} else {
				for ( i=1; i<PartyChatCommands.length; i++ ) {
					let ChatCommand = PartyChatCommands[i];
					const Alias = ChatCommand.cmds;
					const FoundAlias = Alias.find(item => item == args[0]);
					if ( FoundAlias ) {
						const AliasString = Alias.join(', ');
						const Title = `» List of Alias's: ${AliasString}`;
						let Message = Title.split(' ').join('\u{00A0}');
						let MySteamID = MyPersonaAPI.GetXuid();
						PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MySteamID} chat ${Message}`);
						break;
					}
				}
			}
		}
	});
	PartyChatCommands.push({
		title: 'Gay Test (!\u{200B}gay)',
		cmds: ['gay', 'fag', 'gaycheck', 'gc', 'fc', 'fagcheck', 'faggot', 'homo'],
		exec: (cmd, args, sender) => {
			let FagMsg = sender != '>.<' ? 'A FAG' : 'STRAIGHT';
			let Message = `Your test result shows that you are ${FagMsg}`.split(' ').join('\u{00A0}');
			let MySteamID = MyPersonaAPI.GetXuid();
			PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MySteamID} chat ${Message}`);
		}
	});
	PartyChatCommands.push({
		title: 'Start Queue (!\u{200B}startq)',
		cmds: ['start', 'startq', 'startqueue', 'queue', 'q'],
		exec: (cmd, args) => { 
			let ForceTeam = ( args[0] && args[0].toLowerCase() == 't' ) && 't' || 'ct';
			let NotForceTeam = ForceTeam == 't' && 'ct' || 't';
			LobbyAPI.StartMatchmaking('',ForceTeam,'','');
			//LobbyAPI.StartMatchmaking("","t","ct","")
		}
	});
	PartyChatCommands.push({
		title: 'Stop Queue (!\u{200B}stopq)',
		cmds: ['stop', 'stopq', 'stopqueue', 'sq', 's'],
		exec: (cmd, args) => { 
			LobbyAPI.StopMatchmaking()
		}
	});
	PartyChatCommands.push({
		title: 'Restart Queue (!\u{200B}restartq)',
		cmds: ['restart', 'restartq', 'restartqueue', 'rs'],
		exec: (cmd, args) => { 
			LobbyAPI.StopMatchmaking()
			$.Schedule( .5, ()=>{
				LobbyAPI.StartMatchmaking("","ct","t","")
			});
		}
	});
	PartyChatCommands.push({
		title: 'Maps (!\u{200B}maps dust2, safehouse)',
		cmds: ['maps', 'map', 'setmaps', 'changemap', 'changemaps'],
		exec: (cmd, args) => { 

		}
	});
	PartyChatCommands.push({
		title: 'Kick (!\u{200B}kick <partial:name>|<steamid>|<friendcode>)',
		cmds: ['stop', 'stopq', 'stopqueue'],
		exec: (cmd, args) => { 

		}
	});
	PartyChatCommands.push({
		title: 'Invite (!\u{200B}invite <steamid>|<friendcode>)',
		cmds: ['inv', 'invite', 'add'],
		exec: (cmd, args) => {
			for ( i = 0; i < args.length; i++ ) {
				let SteamID = args[i];
				if ( SteamID.length == 17 ) {
					FriendsListAPI.ActionInviteFriend(SteamID, '')
				}
			}
		}
	});
	PartyChatCommands.push({
		title: 'Crack Checker (!\u{200B}crackcheck)',
		cmds: ['cc', 'crackcheck', 'check', 'crack', 'cracks'],
		exec: (cmd, args) => {
			for ( i = 0; i < PartyListAPI.GetCount(); i++ ) {
				let SteamID = PartyListAPI.GetXuidByIndex(i);
				let SteamName = PartyListAPI.GetFriendName(SteamID);
				$.AsyncWebRequest(`https://csmit195.me/api/lolzteam/${SteamID}`,
					{
						type:"GET",
						complete:function(e){
							let Response = e.responseText.substring(0, e.responseText.length-1);
							let Data = JSON.parse(Response);

							if ( typeof Data != 'undefined' && typeof Data.success == 'undefined' ) {
								let Times = Data.length;
								let Price = Data[0].Price;
								let MarketID = Data[0].MarketID;
								let Link = `https://lolz.guru/market/${MarketID}`;

								let LobbyMSG = `[CrackCheck] ${SteamName} - ${Price}usd - ID: ${MarketID}`;

								let Message = LobbyMSG.split(' ').join('\u{00A0}');
								let MySteamID = MyPersonaAPI.GetXuid();
								PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MySteamID} chat ${Message}`);
							}
						}
					}
				);
			}
		}
	});

	// Ignore Initial Chat
	let party_chat = $.GetContextPanel().FindChildTraverse("PartyChat")
	if(party_chat) {
		let chat_lines = party_chat.FindChildTraverse("ChatLinesContainer")
		if(chat_lines) {
			chat_lines.Children().forEach(el => {
				let child = el.GetChild(0)
				if ( child && child.BHasClass('left-right-flow') && child.BHasClass('horizontal-align-left') ) {
					if ( child.BHasClass('CS_processed') ) return false;
					child.AddClass('CS_processed');
				}
			})
		}
	}

	return {
		PartyChatLoop: ()=>{
			let party_chat = $.GetContextPanel().FindChildTraverse("PartyChat")
			if(party_chat) {
				let chat_lines = party_chat.FindChildTraverse("ChatLinesContainer")
				if(chat_lines) {
					chat_lines.Children().forEach(el => {
						let child = el.GetChild(0)
						if ( child && child.BHasClass('left-right-flow') && child.BHasClass('horizontal-align-left') ) {
							if ( child.BHasClass('CS_processed') ) return false;

							let InnerChild = child.GetChild(child.GetChildCount()-1);
							if ( InnerChild && InnerChild.text ) {
								var Message = InnerChild.text.toLowerCase()
								let Search = Message.search(/!(\w+)\s*(.*)$/i);
								if ( Search != -1 ) { 
									const args = Message.substr(Search).slice(Prefix.length).trim().split(' ');
									const command = args.shift().toLowerCase();

									for ( index=0; index < PartyChatCommands.length; index++ ) {
										const ChatCommand = PartyChatCommands[index];
										for ( i=0; i<ChatCommand.cmds.length; i++ ) {
											const Alias = ChatCommand.cmds[i]; 
											if ( Alias == command ) { 
												ChatCommand.exec(command, args, Message.substr(0, Search-1))
												break;
											}
										}
									}
								}
							}
							
							child.AddClass('CS_processed');
						}
					})
				}
			}
		}
	}
]], 'CSGOMainMenu')();

-- Too clean to put in one of the above panoramas, looks sexy AF
local Date = panorama.loadstring('return ts => new Date(ts * 1000)')()
--#endregion

-- Reset debug mode incase restart of script
CSPanorama.setDebugMode(false)

function Initiate()
	local CSLua = {loops = {}}

	CSLua.Header = ui.new_label('Lua', 'B', '=========  [   $CS Start   ]  =========')
	
	--#region Delayed Auto Accept
	CSLua.AutoAccept = {}
	CSLua.AutoAccept.originalAutoAccept = ui.reference('MISC', 'Miscellaneous', 'Auto-accept matchmaking')
	CSLua.AutoAccept.enable = ui.new_checkbox('Lua', 'B', 'Delayed Auto Accept')
	CSLua.AutoAccept.delay = ui.new_slider('Lua', 'B', 'Auto Accept Delay', 1, 21, 3, true, 's')

	ui.set_visible(CSLua.AutoAccept.delay, false)
	CSPanorama.CS_DelayAutoAccept.toggle(false);

	ui.set_callback(CSLua.AutoAccept.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.AutoAccept.delay, Status)
		CSPanorama.CS_DelayAutoAccept.toggle(Status)
		
		if ( Status ) then
			ui.set(CSLua.AutoAccept.originalAutoAccept, not Status)
		end
	end)
	ui.set_callback(CSLua.AutoAccept.delay, function(self)
		CSPanorama.CS_DelayAutoAccept.updateDelay(ui.get(self))
	end)
	ui.set_callback(CSLua.AutoAccept.originalAutoAccept, function(self)
		if ( ui.get(self) ) then
			ui.set(CSLua.AutoAccept.enable, false)
		end
	end)
	--#endregion

	--#region Auto Derank Score
	CSLua.DerankScore = {}
	CSLua.DerankScore.enable = ui.new_checkbox('Lua', 'B', 'Auto Derank Score')
	CSLua.DerankScore.method = ui.new_multiselect('Lua', 'B', 'Method', {'Round Prestart', 'Round Start', 'During Timeout', 'Round End'})

	ui.set_visible(CSLua.DerankScore.method, false)

	ui.set_callback(CSLua.DerankScore.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.DerankScore.method, Status)
	end)

	function CSLua.DerankScore.MethodState(Method)
		local Found = false
		for index, value in ipairs(ui.get(CSLua.DerankScore.method)) do
			if ( value == Method ) then
				Found = true
				break
			end
		end
		return Found
	end

	function CSLua.DerankScore.Reconnect()
		if CompetitiveMatchAPI.HasOngoingMatch() then
			printDebug('reconnecting')
			return CompetitiveMatchAPI.ActionReconnectToOngoingMatch( '', '', '', '' ), derankcheck
		end
	end

	client.set_event_callback("round_start", function()
		if ui.get(CSLua.DerankScore.enable) and CSLua.DerankScore.MethodState('Round Prestart') then
			client.delay_call(0, client.exec, "disconnect")
			client.delay_call(0.5, function()
				CSLua.DerankScore.Reconnect()
			end)
		end
	end)

	client.set_event_callback("round_end", function()
		if ui.get(CSLua.DerankScore.enable) and CSLua.DerankScore.MethodState('Round End') then
			client.delay_call(0, client.exec, "disconnect")
			client.delay_call(0.5, function()
				CSLua.DerankScore.Reconnect()
			end)
		end
	end)
 
	client.set_event_callback("round_freeze_end", function()
		if ui.get(CSLua.DerankScore.enable) and CSLua.DerankScore.MethodState('Round Start') then
			printDebug('Trying the disconnect')
			client.delay_call(0, client.exec, "disconnect")
			client.delay_call(0.5, function()
				CSLua.DerankScore.Reconnect()
			end)
		end
	end)

	CSLua.DerankScore.Deranking = false
	CSLua.loops[#CSLua.loops + 1] = function()
		if not CSLua.DerankScore.Deranking and ui.get(CSLua.DerankScore.enable) and CSLua.DerankScore.MethodState('During Timeout') and FriendsListAPI.IsGamePaused() and entity.is_alive(entity.get_local_player()) then
			local Team = (entity.get_prop(entity.get_game_rules(), "m_bCTTimeOutActive") == 1 and 'CT' or false) or (entity.get_prop(entity.get_game_rules(), "m_bTerroristTimeOutActive") == 1 and 'T' or false)
			local TimeoutRemaining = 0
			if ( Team == 'CT' ) then
				TimeoutRemaining = entity.get_prop(entity.get_game_rules(), "m_flCTTimeOutRemaining")
			elseif ( Team == 'T' ) then
				TimeoutRemaining = entity.get_prop(entity.get_game_rules(), "m_flTerroristTimeOutRemaining")
			end

			if ( TimeoutRemaining > 0) then
				CSLua.DerankScore.Deranking = true
				client.delay_call(0, client.exec, "disconnect")
				client.delay_call(0.5, function()
					CSLua.DerankScore.Reconnect()
				end)
			end
		end
	end
	client.set_event_callback('player_connect_full', function(e)
		printDebug('someone connected')
		if ( entity.get_local_player() == client.userid_to_entindex(e.userid) ) then
			CSLua.DerankScore.Deranking = false
			printDebug('derank false')
		end
	end)
	--#endregion

	--#region Auto Open CsgoStats.gg
	CSLua.AutoCSGOStats = {}
	CSLua.AutoCSGOStats.enable = ui.new_checkbox('Lua', 'B', 'Auto CSGOStats.gg')

	CSPanorama.CS_AutoCSGOStats.toggle(false);

	ui.set_callback(CSLua.AutoCSGOStats.enable, function(self)
		local Status = ui.get(self)
		CSPanorama.CS_AutoCSGOStats.toggle(Status)
	end)
	--#endregion

	--#region Match Start Beep
	CSLua.MatchStartBeep = {}
	CSLua.MatchStartBeep.enable = ui.new_checkbox('Lua', 'B', 'Match Start Beep')
	CSLua.MatchStartBeep.repeatTimes = ui.new_slider('Lua', 'B', 'Times (x)', 1, 30, 1)
	CSLua.MatchStartBeep.repeatInterval = ui.new_slider('Lua', 'B', 'Interval (ms)', 0, 1000, 250, true, 'ms')
	CSLua.MatchStartBeep.delay = ui.new_slider('Lua', 'B', '% of Match Freezetime', 0, 100, 75, true, '%')

	CSLua.MatchStartBeep.sounds = {
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
	for index, Sound in pairs(CSLua.MatchStartBeep.sounds) do
		ProcessedSounds[#ProcessedSounds + 1] = Sound[2]
		ReferenceSounds[Sound[2]] = Sound[1]
	end	
	CSLua.MatchStartBeep.sounds = ui.new_listbox('Lua', 'B', 'Sounds', ProcessedSounds)
	CSLua.MatchStartBeep.testsound = ui.new_button('Lua', 'B', 'Test Sound', function()
		local SelectedSound = ProcessedSounds[ui.get(CSLua.MatchStartBeep.sounds)+1]
		printDebug(SelectedSound, '>', ReferenceSounds[SelectedSound])
		if ( SelectedSound and SelectedSound ~= '' and ReferenceSounds[SelectedSound] ) then
			CSLua.MatchStartBeep.PlaySound()
		end
	end)

	ui.set_visible(CSLua.MatchStartBeep.delay, false)
	ui.set_visible(CSLua.MatchStartBeep.sounds, false)
	ui.set_visible(CSLua.MatchStartBeep.testsound, false)

	ui.set_visible(CSLua.MatchStartBeep.repeatTimes, false)
	ui.set_visible(CSLua.MatchStartBeep.repeatInterval, false)

	ui.set_callback(CSLua.MatchStartBeep.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.MatchStartBeep.delay, Status)
		ui.set_visible(CSLua.MatchStartBeep.sounds, Status)
		ui.set_visible(CSLua.MatchStartBeep.testsound, Status)

		ui.set_visible(CSLua.MatchStartBeep.repeatTimes, Status)
		ui.set_visible(CSLua.MatchStartBeep.repeatInterval, ui.get(CSLua.MatchStartBeep.repeatTimes) ~= 1 and Status)
	end)

	CSLua.MatchStartBeep.PlaySound = function()
		local SelectedSound = ProcessedSounds[ui.get(CSLua.MatchStartBeep.sounds)+1] or 'Default (Beep)'
		if ( SelectedSound and SelectedSound ~= '' and ReferenceSounds[SelectedSound] ) then
			local Times = ui.get(CSLua.MatchStartBeep.repeatTimes)
			local Interval = ui.get(CSLua.MatchStartBeep.repeatInterval)
			if ( Times == 1 ) then
				CSPanorama.CS_PlaySound(ReferenceSounds[SelectedSound], 'MOUSE')
			else
				for i=1, Times do
					client.delay_call(Times == 1 and 0 or ( ( i - 1 ) * Interval ) / 1000, function()
						printDebug('done')
						CSPanorama.CS_PlaySound(ReferenceSounds[SelectedSound], 'MOUSE')
					end)
				end
			end
		end
	end

	ui.set_callback(CSLua.MatchStartBeep.repeatTimes, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.MatchStartBeep.repeatInterval, Status ~= 1)
	end)
	

	client.set_event_callback('round_start', function()
		if ( ui.get(CSLua.MatchStartBeep.enable) ) then
			local mp_freezetime = cvar.mp_freezetime:get_int()
			local percent = ui.get(CSLua.MatchStartBeep.delay) / 100
			client.delay_call(mp_freezetime * percent, function()
				CSLua.MatchStartBeep.PlaySound()
			end)
		end
	end)
	--#endregion

	--#region Custom Clantag Builder
	CSLua.Clantag = {}
	CSLua.Clantag.last = ''
	CSLua.Clantag.enable = ui.new_checkbox('Lua', 'B', 'Clantag Builder [BETA]')
	CSLua.Clantag.template = ui.new_textbox('Lua', 'B', ' ')
	CSLua.Clantag.helper = ui.new_label('Lua', 'B', 'Helper: type { to get suggestions')

	CSLua.Clantag.processedData = {}

	CSLua.Clantag.data = {
		{'rank', 'competitive ranking', 300, function()
			local currentRank = entity.get_prop(entity.get_player_resource(), 'm_iCompetitiveRanking', entity.get_local_player())
			if ( currentRank == 0 ) then return 'N/A' end

			if ( currentRank ) then
				local CurrentMode = GameStateAPI.GetGameModeInternalName(true)
				local RankLong = CSPanorama.CS_Localize(CurrentMode == 'survival' and '#skillgroup_'..currentRank..'dangerzone' or 'RankName_' .. currentRank)
				local RankName = getRankShortName(RankLong)

				return RankName
			end
		end, 0},
		{'wins', 'competitive wins', 300, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iCompetitiveWins', entity.get_local_player()) or ''
		end, 0},
		{'hp', 'current health', 0.5, function()
			return entity.get_prop(entity.get_local_player(), 'm_iHealth') or 0
		end, 0},
		{'amr', 'current armor', 0.5, function()
			return entity.get_prop(entity.get_local_player(), 'm_ArmorValue') or 0
		end, 0},
		{'loc', 'current location', 0.5, function()
			return entity.get_prop(entity.get_local_player(), 'm_szLastPlaceName') or ''
		end, 0},
		{'kills', 'current kills', 1, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iKills', entity.get_local_player()) or 0
		end, 0},
		{'deaths', 'current deaths', 1, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iDeaths', entity.get_local_player()) or 0
		end, 0},
		{'assists', 'current assists', 1, function()
			return entity.get_prop(entity.get_player_resource(), 'm_iAssists', entity.get_local_player()) or 0
		end, 0},
		{'headchance', 'current headshot chance',  1, function()
			local LocalPlayer = entity.get_local_player()
			local TotalKills = CSLua.Clantag.processedData.kills
			local HeadshotKills = entity.get_prop(entity.get_player_resource(), 'm_iMatchStats_HeadShotKills_Total', entity.get_local_player())
			if ( TotalKills and HeadshotKills ) then				
				return math.ceil( (HeadshotKills / TotalKills) * 100 )
			end
		end, 0},
		{'c4', 'displays BOMB if carrying bomb', 1, function()
			CSLua.Clantag.last = '' -- TEMP
			-- Print C4 if has c4
		end, 0},
		{'wep', 'current weapon name', 0.25, function()
			local LocalPlayer = entity.get_local_player()

			local WeaponENT = entity.get_player_weapon(LocalPlayer)
			if WeaponENT == nil then return end

			local WeaponIDX = entity.get_prop(WeaponENT, "m_iItemDefinitionIndex")
			if WeaponIDX == nil then return end

			local weapon = csgo_weapons[WeaponIDX]
			if weapon == nil then return end
			
			return weapon.name
		end, 0},
		{'ammo', 'current weapon ammo', 0.25, function()
			local LocalPlayer = entity.get_local_player()

			local WeaponENT = entity.get_player_weapon(LocalPlayer)
			if WeaponENT == nil then return end
			
			local Ammo = entity.get_prop(WeaponENT, "m_iClip1")
			if Ammo == nil then return end
			
			return Ammo
		end, 0},
		{'id', 'current steam id', 9999, function()
			return CSPanorama.steamID
		end, 0},
		{'bomb', 'bomb timer countdown', 1, function()
			local c4 = entity.get_all("CSlantedC4")[1]
			if c4 == nil or entity.get_prop(c4, "m_bBombDefused") == 1 or entity.get_local_player() == nil then return '' end
			local c4_time = entity.get_prop(c4, "m_flC4Blow") - globals.curtime()
   			return c4_time ~= nil and c4_time > 0 and math.floor(c4_time) or ''
		end, 0},
		{'doa', 'displays DEAD or ALIVE', 0.5, function()
			return entity.is_alive(entity.get_local_player()) and 'ALIVE' or 'DEAD'
		end, 0},
		{'fps', 'current FPS', 0.05, function()
			return AccumulateFps()
		end, 0},
		{'ping', 'current ping', 0.5, function()
			return math.floor(client.latency()*1000)
		end, 0},
		{'date', 'current date (DD/MM/YY)', 300, function()
			local Data = Date(client.unix_time())
			local Day = string.format("%02d", Data.getDate())
			local Month = string.format("%02d", Data.getMonth()+1)
			return string.format('%s/%s/%s', Day, Month, tostring(Data.getFullYear()):sub(3,4))
		end, 0},
		{'shortday', 'current name of the day (Mon, Wed, Tue)', 300, function()
			local DaysOfWeek = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'}
			local Data = Date(client.unix_time())
			return DaysOfWeek[Data.getDay()+1]
		end, 0},
		{'longday', 'current name of the day (Monday, Wednesday, Tuesday)', 300, function()
			local DaysOfWeek = {'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'}
			local Data = Date(client.unix_time())
			return DaysOfWeek[Data.getDay()+1]
		end, 0},
		{'day', 'current day of the month', 300, function()
			local Data = Date(client.unix_time())
			return string.format("%02d", Data.getDate())
		end, 0},
		{'month', 'current month number', 300, function()
			local Data = Date(client.unix_time())
			return string.format("%02d", Data.getMonth()+1)
		end, 0},
		{'year', 'current year number', 300, function()
			local Data = Date(client.unix_time())
			return tostring(Data.getFullYear()):sub(3,4)
		end, 0},
		{'time12', 'current time in 12 hour time', 1, function()
			local Data = Date(client.unix_time())
			local Hours = Data.getHours()
			local Suffix = Hours > 12 and 'PM' or 'AM'
			Hours = string.format("%02d", Hours > 12 and Hours - 12 or Hours)
			local Minutes = string.format("%02d", Data.getMinutes())
			local Seconds = string.format("%02d", Data.getSeconds())
			return string.format('%s:%s:%s %s', Hours, Minutes, Seconds, Suffix)
		end, 0},
		{'time24', 'current time in 24 hour time', 1, function()
			local Data = Date(client.unix_time())
			local Hours = string.format("%02d", Data.getHours())
			local Minutes = string.format("%02d", Data.getMinutes())
			local Seconds = string.format("%02d", Data.getSeconds())
			return string.format('%s:%s:%s', Hours, Minutes, Seconds)
		end, 0},
		{'hour12', 'hour in 12 hour time', 1, function()
			local Data = Date(client.unix_time())
			local Hours = Data.getHours()
			return string.format("%02d", Hours > 12 and Hours - 12 or Hours)
		end, 0},
		{'hour24', 'hour in 24 hour time', 1, function()	
			local Data = Date(client.unix_time())
			return Data.getHours()
		end, 0},
		{'mins', 'current minutes in system time', 1, function()
			local Data = Date(client.unix_time())
			return string.format("%02d", Data.getMinutes())
		end, 0},
		{'secs', 'current seconds in system time', 1, function()
			local Data = Date(client.unix_time())
			return string.format("%02d", Data.getSeconds())
		end, 0},
		{'timesuffix', '12 hour time suffix', 1, function()
			local Data = Date(client.unix_time())
			local Hours = Data.getHours()
			return Hours > 12 and 'PM' or 'AM'
		end, 0}
	}
	
	ui.set_visible(CSLua.Clantag.template, false)
	ui.set_visible(CSLua.Clantag.helper, false)

	ui.set_callback(CSLua.Clantag.enable, function(self)
		local Status = ui.get(self)
		if ( not Status ) then
			client.set_clan_tag('')
		end
		CSLua.Clantag.last = ''
		ui.set_visible(CSLua.Clantag.template, Status)
		ui.set_visible(CSLua.Clantag.helper, Status)
	end)

	-- Helper Code
	local LastTemplateText = ui.get(CSLua.Clantag.template)
	client.set_event_callback('post_render', function()
		local TemplateText = ui.get(CSLua.Clantag.template)
		if ( TemplateText ~= LastTemplateText ) then
			LastTemplateText = TemplateText
			local Match = TemplateText:match('{(%a*%d*)$')
			if ( Match ) then
				local FoundMatch = false
				if ( Match:len() > 0 ) then
					for i, v in ipairs(CSLua.Clantag.data) do
						if ( v[1]:sub(1, Match:len()) == Match:lower() ) then
							FoundMatch = v
							break;
						end
					end
					if ( FoundMatch ) then
						ui.set(CSLua.Clantag.helper, '{' .. FoundMatch[1] .. '} - ' .. FoundMatch[2])
					else
						ui.set(CSLua.Clantag.helper, 'no matches found for {' .. Match .. '}' )
					end
				else
					local cmds = {}
					for i, v in ipairs(CSLua.Clantag.data) do
						cmds[#cmds + 1] = v[1]
					end
					ui.set(CSLua.Clantag.helper, table.concat(cmds, ', ') )
				end
			else
				ui.set(CSLua.Clantag.helper, 'Helper: type { to get suggestions' )
			end
		end
	end)

	CSLua.loops[#CSLua.loops + 1] = function()
		if ( not ui.get(CSLua.Clantag.enable) ) then return end
		if ( not entity.get_local_player() ) then return end

		-- DATA CALCULATIONS
		for index, value in ipairs(CSLua.Clantag.data) do
			local tag = value[1]
			local desc = value[2]
			local delay = value[3]
			local callfunc = value[4]
			
			if ( globals.curtime() > value[5] ) then
				local Output = callfunc()
				if ( Output == nil ) then
					CSLua.Clantag.processedData[tag] = ''
				elseif ( Output ) then
					CSLua.Clantag.processedData[tag] = Output
				end
				value[5] = globals.curtime() + delay
			end
		end
		
		local newClantag = processTags(ui.get(CSLua.Clantag.template), CSLua.Clantag.processedData)
		if ( CSLua.Clantag.last ~= newClantag ) then
			client.set_clan_tag(newClantag)
			CSLua.Clantag.last = newClantag
		end
	end

	client.set_event_callback('player_connect_full', function()
		CSLua.Clantag.last = ''
		for index, value in ipairs(CSLua.Clantag.data) do
			value[5] = 0
		end
	end)
	client.set_event_callback('round_start', function()
		CSLua.Clantag.last = ''
	end)
	--#endregion

	--#region Custom Killsay Builder
	CSLua.CustomKillSay = {}
	CSLua.CustomKillSay.enable = ui.new_checkbox('Lua', 'B', 'Killsay Builder [BETA]')
	ui.set_visible(CSLua.CustomKillSay.enable, false)
	CSLua.CustomKillSay.template = ui.new_textbox('Lua', 'B', ' ')
	CSLua.CustomKillSay.helper = ui.new_label('Lua', 'B', 'Helper: type { to get suggestions')

	CSLua.CustomKillSay.processedData = {}

	
	ui.set_visible(CSLua.CustomKillSay.template, false)
	ui.set_visible(CSLua.CustomKillSay.helper, false)

	ui.set_callback(CSLua.CustomKillSay.enable, function(self)
		local Status = ui.get(self)
		if ( not Status ) then
			client.set_clan_tag('')
		end
		ui.set_visible(CSLua.CustomKillSay.template, Status)
		ui.set_visible(CSLua.CustomKillSay.helper, Status)
	end)

	-- Helper Code
	local helperData = {
		{'kills', 'victims kills', function(ent)
			return
		end},
	}

	local LastKillsayText = ui.get(CSLua.CustomKillSay.template)
	client.set_event_callback('post_render', function()
		local TemplateText = ui.get(CSLua.CustomKillSay.template)
		if ( TemplateText ~= LastKillsayText ) then
			LastKillsayText = TemplateText
			local Match = TemplateText:match('{(%a*%d*)$')
			if ( Match ) then
				local FoundMatch = false
				if ( Match:len() > 0 ) then
					for i, v in ipairs(CSLua.CustomKillSay.data) do
						if ( v[1]:sub(1, Match:len()) == Match:lower() ) then
							FoundMatch = v
							break;
						end
					end
					if ( FoundMatch ) then
						ui.set(CSLua.CustomKillSay.helper, '{' .. FoundMatch[1] .. '} - ' .. FoundMatch[2])
					else
						ui.set(CSLua.CustomKillSay.helper, 'no matches found for {' .. Match .. '}' )
					end
				else
					local cmds = {}
					for i, v in ipairs(CSLua.CustomKillSay.data) do
						cmds[#cmds + 1] = v[1]
					end
					ui.set(CSLua.CustomKillSay.helper, table.concat(cmds, ', ') )
				end
			else
				ui.set(CSLua.CustomKillSay.helper, 'Helper: type { to get suggestions' )
			end
		end
	end)

	client.set_event_callback('round_start', function()
		--processTags(ui.get(CSLua.CustomKillSay.template))
	end)
	--#endregion

	--#region Report Enemy Tool
	CSLua.ReportTool = {}
	CSLua.ReportTool.enable = ui.new_checkbox('Lua', 'B', 'Report Tool')
	
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
	CSLua.ReportTool.types = ui.new_multiselect('Lua', 'B', 'Types', ReportTypeNames)
	CSLua.ReportTool.submit = ui.new_button('Lua', 'B', 'Report!', function()
		local Types = ui.get(CSLua.ReportTool.types)
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

	ui.set_callback(CSLua.ReportTool.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.ReportTool.types, Status)
		ui.set_visible(CSLua.ReportTool.submit, Status)
	end)
	ui.set_visible(CSLua.ReportTool.types, false)
	ui.set_visible(CSLua.ReportTool.submit, false)
	--#endregion

	--#region Crack Checker
	CSLua.CrackTool = {state=false}
	CSLua.CrackTool.enable = ui.new_checkbox('Lua', 'B', 'Crack Checker')
	CSLua.CrackTool.customformatEnable = ui.new_checkbox('Lua', 'B', 'Custom Format')
	CSLua.CrackTool.customformat = ui.new_textbox('Lua', 'B', ' ')
	CSLua.CrackTool.target = ui.new_combobox('Lua', 'B', 'Target', {'Everyone', 'Teammates', 'Enemies'})
	CSLua.CrackTool.output = ui.new_multiselect('Lua', 'B', 'Output', {'Local Chat', 'Party Chat', 'Game Chat', 'Team Chat', 'Console'})

	ui.set_visible(CSLua.CrackTool.customformatEnable,  false)
	
	ui.set(CSLua.CrackTool.customformat, '[CrackCheck] Acc {name} sold {times} times for {price}usd on LolzTeam, market ID: {marketID}')

	CSLua.QueueChatMessages = {
		['msgs'] = {},
		['state'] = false
	}
	
	CSLua.QueueChatMessages.sendNext = function()
		local NextMessage = CSLua.QueueChatMessages.msgs[1]
		if ( NextMessage ) then
			local type = NextMessage[1]
			local msg = NextMessage[2]
			client.exec(type .. " ", msg)
		end
	end

	client.set_event_callback('player_chat', function (e)
		if ( #CSLua.QueueChatMessages.msgs > 0 ) then
			local ent, name, text = e.entity, e.name, e.text
			if ( ent == entity.get_local_player() and CSLua.QueueChatMessages.msgs[1][2]:find(esc(text)) ) then
				printDebug('Confirmed message: ', text)

				if ( #CSLua.QueueChatMessages.msgs > 0 ) then
					table.remove(CSLua.QueueChatMessages.msgs, 1)
					client.delay_call(1, CSLua.QueueChatMessages.sendNext)
				end
			end
		end
	end)

	CSLua.ChatMethods = {
		['Party Chat'] = function(msg)
			PartyListAPI.SessionCommand('Game::Chat', string.format('run all xuid %s chat %s', CSPanorama.steamID, msg:gsub(' ', ' ')))
		end,
		['Game Chat'] = function(msg)
			CSLua.QueueChatMessages.msgs[#CSLua.QueueChatMessages.msgs + 1] = {'say', msg}
			if ( #CSLua.QueueChatMessages.msgs == 1 ) then
				CSLua.QueueChatMessages.sendNext()
			end
		end,
		['Team Chat'] = function(msg)
			CSLua.QueueChatMessages.msgs[#CSLua.QueueChatMessages.msgs + 1] = {'say_team', msg}
			if ( #CSLua.QueueChatMessages.msgs == 1 ) then
				CSLua.QueueChatMessages.sendNext()
			end
		end,
		['Console'] = function(...)
			print(...)
		end
	}
	
	if ( sendChatSuccess ) then
		CSLua.ChatMethods['Local Chat'] = function(msg)
			CS_SendChat(msg)
		end
	end

	ui.set(CSLua.CrackTool.customformat)

	CSLua.CrackTool.CheckCrack = function(SteamID, Name, Callback)
		local URL = 'https://csmit195.me/api/lolzteam/' .. SteamID
		http.request('GET', URL, function(success, response)
			if not CSLua.CrackTool.state then return end
			if not success or response.status ~= 200 then
				print('[CRACK CHECKER] ', 'Error accessing our api to check ', Name, '\'s sale history. Trying again.');
				printDebug(response.body);
				return CSLua.CrackTool.CheckCrack(SteamID, Name, Callback)
			end
			local Response = json.parse(response.body)
			if ( Response.error ) then
				print('[CRACK CHECKER] Error: ', Response.error)
			elseif ( Response and Response.success ~= nil and Response.success == false ) then
				print('[CRACK CHECKER] ', Name, '\'s account was not sold on Lolz.Team.')
			elseif ( Response and Response.success ) then
				local data = Response.Data
				local ReplaceData = {}
				ReplaceData.name = Name
				ReplaceData.id = SteamID
				ReplaceData.times = #data
				ReplaceData.price = data[1].Price
				ReplaceData.marketid = data[1].MarketID
				ReplaceData.link =  'https://lolz.guru/market/'..ReplaceData.marketid

				local Prices = {}
				local Links = {}
				local Currency = ''
				for index, value in ipairs(data) do
					Prices[#Prices + 1] = value.Price
					Links[#Links + 1] = value.MarketID
					Currency = value.Currency
				end
				ReplaceData.min = math.min(unpack(Prices))
				ReplaceData.max = math.max(unpack(Prices))
				
				ReplaceData.links = table.concat(Links, ', ')

				local Default = '[CrackCheck] Acc {name} sold {times} times for {price}usd on LolzTeam, market ID: {marketID}'
				if ( ui.get(CSLua.CrackTool.customformatEnable) ) then
					Default = ui.get(CSLua.CrackTool.customformat)
				end
				local Msg = processTags(Default, ReplaceData);
				for index, value in ipairs(ui.get(CSLua.CrackTool.output)) do
					CSLua.ChatMethods[value](Msg)
				end
			end
			Callback()
		end)
	end

	CSLua.CrackTool.StartStop = function(uiIndex)
		local State = ui.name(uiIndex) == 'Start'
		CSLua.CrackTool.state = State
		ui.set_visible(CSLua.CrackTool.start, not State)
		ui.set_visible(CSLua.CrackTool.stop, State)
		if ( State ) then
			local Target = ui.get(CSLua.CrackTool.target)
			local Targets = {}
			for Player=1, globals.maxplayers() do
				if ( not CSLua.CrackTool.state ) then break end
				local SteamXUID = GameStateAPI.GetPlayerXuidStringFromEntIndex(Player)
				if ( SteamXUID and SteamXUID:len() == 17 ) then
					if ( Target == 'Everyone' ) then
						Targets[#Targets + 1] = {SteamXUID, entity.get_player_name(Player)}
					elseif ( Target == 'Teammates' and not entity.is_enemy(Player) ) then
						Targets[#Targets + 1] = {SteamXUID, entity.get_player_name(Player)}
					elseif ( Target == 'Enemies' and entity.is_enemy(Player) ) then
						Targets[#Targets + 1] = {SteamXUID, entity.get_player_name(Player)}
					end
				end
			end
			local Completed = 0
			if ( #Targets > 0 ) then
				for i, v in ipairs(Targets) do
					client.delay_call(0.1*(i-1), function()
						CSLua.CrackTool.CheckCrack(v[1], v[2], function()
							Completed = Completed + 1
							if ( Completed == #Targets ) then
								ui.set_visible(CSLua.CrackTool.start, true)
								ui.set_visible(CSLua.CrackTool.stop, false)
							end
						end)
					end)
				end
			elseif ( #Targets == 0 ) then
				ui.set_visible(CSLua.CrackTool.start, true)
				ui.set_visible(CSLua.CrackTool.stop, false)
			end
		end
	end
	CSLua.CrackTool.start = ui.new_button('Lua', 'B', 'Start', CSLua.CrackTool.StartStop)
	CSLua.CrackTool.stop = ui.new_button('Lua', 'B', 'Stop', CSLua.CrackTool.StartStop)

	ui.set_callback(CSLua.CrackTool.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.CrackTool.customformatEnable, Status)
		ui.set_visible(CSLua.CrackTool.customformat, ui.get(CSLua.CrackTool.customformatEnable) and Status)
		ui.set_visible(CSLua.CrackTool.target, Status)
		ui.set_visible(CSLua.CrackTool.output, Status)
		ui.set_visible(CSLua.CrackTool.start, not CSLua.CrackTool.state and Status)
		ui.set_visible(CSLua.CrackTool.stop, CSLua.CrackTool.state and Status)
	end)

	ui.set_callback(CSLua.CrackTool.customformatEnable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.CrackTool.customformat, Status)
	end)
	
	ui.set_visible(CSLua.CrackTool.customformatEnable, false)
	ui.set_visible(CSLua.CrackTool.customformat, false)
	ui.set_visible(CSLua.CrackTool.target, false)
	ui.set_visible(CSLua.CrackTool.output, false)
	ui.set_visible(CSLua.CrackTool.start, false)
	ui.set_visible(CSLua.CrackTool.stop, false)
	--#endregion

	--#region Face.it Checker
	CSLua.FaceITTool = {state=false}
	CSLua.FaceITTool.enable = ui.new_checkbox('Lua', 'B', 'FaceIT Checker')
	CSLua.FaceITTool.customformatEnable = ui.new_checkbox('Lua', 'B', 'Custom Format')
	CSLua.FaceITTool.customformat = ui.new_textbox('Lua', 'B', ' ')
	CSLua.FaceITTool.target = ui.new_combobox('Lua', 'B', 'Target', {'Everyone', 'Teammates', 'Enemies'})
	CSLua.FaceITTool.output = ui.new_multiselect('Lua', 'B', 'Output', {'Local Chat', 'Party Chat', 'Game Chat', 'Team Chat', 'Console'})
	
	ui.set_visible(CSLua.FaceITTool.customformatEnable,  false)	
	ui.set(CSLua.FaceITTool.customformat, '[FaceIT Checker] User {name} has a KD/R of {kdr}!')

	CSLua.FaceITTool.StartStop = function(uiIndex)
		local State = ui.name(uiIndex) == 'Start'
		CSLua.FaceITTool.state = State
		ui.set_visible(CSLua.FaceITTool.start, not State)
		ui.set_visible(CSLua.FaceITTool.stop, State)
		if ( State ) then
			local Target = ui.get(CSLua.FaceITTool.target)
			local Targets = {}
			for Player=1, globals.maxplayers() do
				if ( not CSLua.FaceITTool.state ) then break end
				local SteamXUID = GameStateAPI.GetPlayerXuidStringFromEntIndex(Player)
				if ( SteamXUID:len() > 5 ) then
					if ( Target == 'Everyone' ) then
						Targets[#Targets + 1] = {SteamXUID, entity.get_player_name(Player)}
					elseif ( Target == 'Teammates' and not entity.is_enemy(Player) ) then
						Targets[#Targets + 1] = {SteamXUID, entity.get_player_name(Player)}
					elseif ( Target == 'Enemies' and entity.is_enemy(Player) ) then
						Targets[#Targets + 1] = {SteamXUID, entity.get_player_name(Player)}
					end
				end
			end
			local Completed = 0
			if ( #Targets > 0 ) then
				local OutputMethods = ui.get(CSLua.FaceITTool.output)
				for i, v in ipairs(Targets) do
					local URL = 'https://csmit195.me/api/faceit/' .. v[1]

					http.request('GET', URL, function(success, response)
						if not success or response.status ~= 200 or not CSLua.FaceITTool.state then return end
						local data = json.parse(response.body)
						if ( data and data.success ~= nil and data.success == false ) then
							printDebug('well fuck, we found nothing')
						elseif ( data and data.id and data.matches ) then
							local ReplaceData = {}
							ReplaceData.name = v[2]
							ReplaceData.steamid = v[1]
							ReplaceData.id = data.id
							ReplaceData.user = data.nickname
							ReplaceData.country = data.country
							ReplaceData.kdratio = data.kdratio
							ReplaceData.win = data.winratio .. '%'
							ReplaceData.hschance = data.hschance
							ReplaceData.matches = data.matches

							local Default = '[FaceIT Checker] {name} has a faceit acc ({user}) with {win} chance over {matches} games!'
							if ( ui.get(CSLua.FaceITTool.customformatEnable) ) then
								Default = ui.get(CSLua.FaceITTool.customformat)
							end
							local Msg = processTags(Default, ReplaceData);
							for index, value in ipairs(OutputMethods) do
								CSLua.ChatMethods[value](Msg)
							end
						end

						Completed = Completed + 1
						if ( Completed == #Targets ) then
							CSLua.FaceITTool.state = false

							ui.set_visible(CSLua.FaceITTool.start, true)
							ui.set_visible(CSLua.FaceITTool.stop, false)
						end
					end)
				end
			elseif ( #Targets == 0 ) then
				ui.set_visible(CSLua.FaceITTool.start, true)
				ui.set_visible(CSLua.FaceITTool.stop, false)
			end
		end
	end
	CSLua.FaceITTool.start = ui.new_button('Lua', 'B', 'Start', CSLua.FaceITTool.StartStop)
	CSLua.FaceITTool.stop = ui.new_button('Lua', 'B', 'Stop', CSLua.FaceITTool.StartStop)

	ui.set_callback(CSLua.FaceITTool.enable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.FaceITTool.customformatEnable, Status)
		ui.set_visible(CSLua.FaceITTool.customformat, ui.get(CSLua.FaceITTool.customformatEnable) and Status)
		ui.set_visible(CSLua.FaceITTool.target, Status)
		ui.set_visible(CSLua.FaceITTool.output, Status)
		ui.set_visible(CSLua.FaceITTool.start, not CSLua.FaceITTool.state and Status)
		ui.set_visible(CSLua.FaceITTool.stop, CSLua.FaceITTool.state and Status)
	end)

	ui.set_callback(CSLua.FaceITTool.customformatEnable, function(self)
		local Status = ui.get(self)
		ui.set_visible(CSLua.FaceITTool.customformat, Status)
	end)
	
	ui.set_visible(CSLua.FaceITTool.customformatEnable, false)
	ui.set_visible(CSLua.FaceITTool.customformat, false)
	ui.set_visible(CSLua.FaceITTool.target, false)
	ui.set_visible(CSLua.FaceITTool.output, false)
	ui.set_visible(CSLua.FaceITTool.start, false)
	ui.set_visible(CSLua.FaceITTool.stop, false)
	--#endregion

	--#region Party Chat Utilities
	CSLua.PartyChatUtils = {}
	CSLua.PartyChatUtils.enable = ui.new_checkbox('Lua', 'B', 'Party Chat Utilities')

	ui.set(CSLua.PartyChatUtils.enable, true)

	local LastTick = globals.realtime()
	client.set_event_callback('post_render', function()
		if ( globals.realtime() - LastTick > 0.25 and ui.get(CSLua.PartyChatUtils.enable) ) then
			CSPanoramaMainMenu.PartyChatLoop()
			LastTick = globals.realtime()
		end
	end)
	--#endregion

 	--#region DebugOptions
	CSLua.DebugOptions = {}
	CSLua.DebugOptions.enable = ui.new_checkbox('Lua', 'B', 'Debug Mode (console)')
	ui.set_callback(CSLua.DebugOptions.enable, function(self)
		local Status = ui.get(self)
		Options.debugMode = Status
		CSPanorama.setDebugMode(Status)
	end)
	--#endregion

	CSLua.Footer = ui.new_label('Lua', 'B', '=========  [   $CS Finish   ]  =========')

	--#region Paint Draw Loops
	client.set_event_callback('paint', function()
		for index, func in ipairs(CSLua.loops) do
			func()
		end
	end)
	--#endregion

	--#region Player List Adjustments
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
	MessageRepeater.header = ui.new_label('Players', 'Adjustments', '=---------  [  $CS Adjustments  ]  ---------=')
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
			if ( entity.is_enemy(Player) and ui.get(MessageRepeater.repeatMessages) ) then
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
	--#endregion
end

--#region Utilities and Libraries
function processTags(str, vars)
	if not vars then
		vars = str
		str = vars[1]
	  end
	  return (string.gsub(str, "({([^}]+)})",
		function(whole,i)
		  return vars[i:lower()] or whole
		end))
end

function printDebug(...)
	if ( not Options.debugMode ) then return end
	print('[$CS]', ...)
end

function esc(x)
	return (x:gsub('%%', '%%%%'):gsub('^%^', '%%^'):gsub('%$$', '%%$'):gsub('%(', '%%('):gsub('%)', '%%)'):gsub('%.', '%%.'):gsub('%[', '%%['):gsub('%]', '%%]'):gsub('%*', '%%*'):gsub('%+', '%%+'):gsub('%-', '%%-'):gsub('%?', '%%?'))
end

function getRankShortName(LongRankName)
	if not LongRankName then return false end
	local RomanNumerals = {'III', 'II', 'I'}
	local Rank = LongRankName:gsub('The ', ' '):gsub('%l', '')
	for RomanIndex = 1, #RomanNumerals do
		if ( Rank:find(RomanNumerals[RomanIndex]) ) then
		Rank = Rank:gsub(RomanNumerals[RomanIndex], #RomanNumerals + 1 - RomanIndex)
		end
		Rank = Rank:gsub(' ', '')
	end
	return Rank
end

-- Yoink
sendChatSuccess, CS_SendChat = pcall(function()
	local signature = '\x55\x8B\xEC\x83\xEC\x08\x8B\x15\xCC\xCC\xCC\xCC\x0F\x57'
	local signature_gHud = '\xB9\xCC\xCC\xCC\xCC\x88\x46\x09'
	local signature_FindElement = '\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x57\x8B\xF9\x33\xF6\x39\x77\x28'
	local match = client.find_signature('client.dll', signature) or error('client_find_signature fucked up')
	local line_goes_through_smoke = ffi.cast('lgts', match) or error('ffi.cast fucked up')
	local match = client.find_signature('client.dll', signature_gHud) or error('signature not found')
	local hud = ffi.cast('void**', ffi.cast('char*', match) + 1)[0] or error('hud is nil')
	local helement_match = client.find_signature('client.dll', signature_FindElement) or error('FindHudElement not found')
	local hudchat = ffi.cast('FindHudElement_t', helement_match)(hud, 'CHudChat') or error('CHudChat not found')
	local chudchat_vtbl = hudchat[0] or error('CHudChat instance vtable is nil')
	local print_to_chat = ffi.cast('ChatPrintf_t', chudchat_vtbl[27])

	return function (text)
		print_to_chat(hudchat, 0, 0, text)
	end
end)

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
--#endregion

Initiate()