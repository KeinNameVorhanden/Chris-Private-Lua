local Loader = panorama.loadstring([[
	let Status = {
		finished: false
	};
	
	$.AsyncWebRequest("https://github.com/csmit195/Chris-Private-Lua/raw/master/main.lua", {
			type:"GET",
			complete:function(e){
				Status.finished = true;
				Status.code = e.responseText;
			}
		}
	);
	
	return Status;
]])()

local function Loop()
	if ( Loader.finished ) then
		loadstring(Loader.code)()
		print('Loaded Chris\'s Public Lua')
	else
		client.delay_call(0.1, Loop)
	end
end
Loop()