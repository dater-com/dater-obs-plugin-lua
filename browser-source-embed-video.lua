obs            = obslua
source_name    = ""
browser_source = ""
player         = ""
video_id       = ""
video_id2      = ""
url            = ""
autostart      = false
loop           = false
start          = 0
settings_      = nil
hotkey_id_reset     = obs.OBS_INVALID_HOTKEY_ID
hotkey_id_pause     = obs.OBS_INVALID_HOTKEY_ID

function set_url_text(text)   
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "url", text)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

function on_event(event)

end

function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function settings_modified(props, prop, settings)
	local player_setting = obs.obs_data_get_string(settings, "player")
	local p_browser_source = obs.obs_properties_get(props, "browser_source")
	local p_video_id = obs.obs_properties_get(props, "video_id")
	local p_video_id2 = obs.obs_properties_get(props, "video_id2")	
	local p_start = obs.obs_properties_get(props, "start")	

	if (player_setting == "YouTube") then
		obs.obs_property_set_visible(p_browser_source, true)
		obs.obs_property_set_visible(p_video_id, true)
		obs.obs_property_set_visible(p_video_id2, true)		
		obs.obs_property_set_visible(p_start, true)		
	elseif (player_setting == "Vimeo") then
		obs.obs_property_set_visible(p_browser_source, true)
		obs.obs_property_set_visible(p_video_id, true)
		obs.obs_property_set_visible(p_video_id2, false)				
		obs.obs_property_set_visible(p_start, false)
	end
	return true
end

function script_properties()
	local props = obs.obs_properties_create()
	local p_player = obs.obs_properties_add_list(props, "player", "Video Player", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(p_player, "YouTube", "youtube")
	obs.obs_property_list_add_string(p_player, "Vimeo", "vimeo")	

	obs.obs_property_set_modified_callback(p_player, settings_modified)

	local p = obs.obs_properties_add_list(props, "browser_source", "Browser Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "browser_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	
	obs.obs_properties_add_text(props, "video_id", "Video ID", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "video_id2", "Video ID2+", obs.OBS_TEXT_DEFAULT)
 	obs.obs_properties_add_bool(props, "autostart", "Autostart video when source is activated?")
	obs.obs_properties_add_bool(props, "loop", "Loop video(s)?")
	obs.obs_properties_add_int(props, "start", "Start time (secs)", 0, 10000, 1)

	settings_modified(props, nil, settings_)

	return props
end

function script_description()
	return "Sets a browser source to play a YouTube or Vimeo video using an embedded player, with input parameters."
end

function script_update(settings)
	player = obs.obs_data_get_string(settings, "player")
	source_name = obs.obs_data_get_string(settings, "browser_source")
	video_id = obs.obs_data_get_string(settings, "video_id")
	video_id2 = obs.obs_data_get_string(settings, "video_id2")
	if video_id2 ~= "" then video_id2 = "," ..video_id2 end
	local autostart = obs.obs_data_get_bool(settings, "autostart")
	if autostart == true then autostart = 1 else autostart = 0 end
	local loop = obs.obs_data_get_bool(settings, "loop")
	if loop == true then loop = 1 else loop = 0 end
	local start = obs.obs_data_get_int(settings, "start")

	if player == "YouTube" then
		url = "https://www.youtube.com/embed/" .. video_id .. "?playlist=" .. video_id .. video_id2 .. "&loop=" .. loop .. "&autoplay=" .. autostart .. "&start=" .. start
	elseif player == "Vimeo" then
		url = "https://player.vimeo.com/video/" .. video_id .. "?autoplay=" .. autostart .. "&loop=" .. loop .. " frameborder=0 allow=autoplay; fullscreen; picture-in-picture; allowfullscreen"
	else
		url = ""
	end
	set_url_text(url)
end

function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "player", "YouTube")
	obs.obs_data_set_default_string(settings, "browser_source", "-----")
	obs.obs_data_set_default_int(settings, "start", 0)	
end

function script_save(settings)
	obs.obs_data_array_release(hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
end

function script_load(settings)
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_show", source_activated)
	obs.signal_handler_connect(sh, "source_hide", source_deactivated)

    obs.obs_hotkey_load(hotkey_id_reset, hotkey_save_array_reset)
	obs.obs_hotkey_load(hotkey_id_pause, hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
	obs.obs_data_array_release(hotkey_save_array_pause)

	obs.obs_frontend_add_event_callback(on_event)

	settings_ = settings

	script_update(settings)
end