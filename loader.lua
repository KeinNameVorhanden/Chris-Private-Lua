-- $CP Auto Updater (no fail, unlike the other shit one people have)
local CPUpdater = panorama.loadstring([[
	var CPUpdater = {
		updating: false,
		finished: false
	};
	
	CPUpdater.GetLatest = ()=>{
		CPUpdater.updating = true;
		CPUpdater.finished = false;
		$.AsyncWebRequest("https://raw.githubusercontent.com/csmit195/Chris-Private-Lua/master/main.lua",
			{
				type:"GET",
				complete:function(e){
					CPUpdater.updating = false;
					CPUpdater.finished = true;
					CPUpdater.code = e.responseText;
				}
			}
		);
	}
	
	CPUpdater.Check = ()=> {
		if ( CPUpdater.updating && !CPUpdater.finished ) {
			return false
		}
		return true
	}
	
	CPUpdater.GetCode = ()=>{
		if ( !CPUpdater.updating && CPUpdater.finished ) {
			return CPUpdater.code;
		}
	}
	
	return CPUpdater;
]])()

CPUpdater.GetLatest();
local function LoopCheck()
	if ( CPUpdater.Check() ) then
		loadstring(CPUpdater.GetCode())()
		print('Loaded Chris\'s Private Lua')
		return true
	end
	client.delay_call(0.1, LoopCheck)
	return false
end
LoopCheck()

--loadstring()();