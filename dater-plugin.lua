local ffi = require("ffi")
-- local SSL = require("tls")
local socket = require("ljsocket")
local streamUrl = "rtsp://rtsp.stream/movie";

print("Starting Dater Obs Plugin..!")
obs = obslua

function script_description()
  print("Dater Streams")
  return [[Get your current match stream and play it in VLC Source automatically]]
end


function script_properties()
	local props = obs.obs_properties_create()

	local vlc_player = obs.obs_properties_add_list(props, "vlc_source", "VLC Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()

  if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "vlc_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(vlc_player, name, name)
			end
		end
	end
	obs.obs_property_set_modified_callback(vlc_player, settings_modified)

  obs.source_list_release(sources)
	
	obs.obs_properties_add_text(props, "user_id", "Dater userId", obs.OBS_TEXT_DEFAULT)
 	obs.obs_properties_add_bool(props, "autostart", "Autostart playing")
	obs.obs_properties_add_int(props, "start_in_secs", "Start time (secs)", 0, 10000, 1)

	settings_modified(props, nil, settings_)

	return props
end

function settings_modified(props, prop, settings)
	local p_vlc_source = obs.obs_properties_get(props, "vlc_source")
	local p_user_id = obs.obs_properties_get(props, "user_id")
	local p_autostart = obs.obs_properties_get(props, "autostart")	
	local p_start_in_secs = obs.obs_properties_get(props, "start_in_secs")	
	local vlc_source_name = obs.obs_data_get_string(settings, "vlc_source")

  -- print("VLC Source changed: "..p_vlc_source.."\n");
  print('Settings changed..');
  print("New VLC source name: "..vlc_source_name);
  return true
end


local host = "us-central1-dater3-dev.cloudfunctions.net"
local functionName = "api-locationByIp";

local socket = assert(socket.create("inet", "stream", "tcp"))
assert(socket:set_blocking(false))
assert(socket:connect(host, "http"))

print("Request page: http://"..host.."/"..functionName.."\n\n");

while true do
    if socket:is_connected() then
        assert(socket:send(
            "GET /"..functionName.." HTTP/1.1\r\n"..
            "Host: "..host.."\r\n"..
            "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:64.0) Gecko/20100101 Firefox/64.0\r\n"..
            "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
            "Accept-Language: nb,nb-NO;q=0.9,en;q=0.8,no-NO;q=0.6,no;q=0.5,nn-NO;q=0.4,nn;q=0.3,en-US;q=0.1\r\n"..
            --"Accept-Encoding: gzip, deflate\r\n"..
            "DNT: 1\r\n"..
            "Connection: keep-alive\r\n"..
            "Upgrade-Insecure-Requests: 1\r\n"..
            "\r\n"
        ))

        local str = ""
        local total_length

        while true do
            local chunk, err = socket:receive()

            if chunk then
                str = str .. chunk

                if not total_length then
                    total_length = tonumber(str:match("Content%-Length: (%d+)"))
                end

                if #str >= total_length then
                    print(str)
                    print("\nDone!\n");
                    return
                end
            elseif err ~= "timeout" then
                error(err)
                return;
            end
        end
    else
        socket:poll_connect()
    end
end

