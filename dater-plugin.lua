---@diagnostic disable: lowercase-global
local socket = require("lib/ljsocket")
local json = require "lib/json"

local stream_url = "rtsp://rtsp.stream/pattern";
local devEnvironment = 'Development';
local prodEnvironment = 'Production';
local activeDevEnironment = prodEnvironment;
local devObsStreamInfoHost = 'us-central1-dater3-dev.cloudfunctions.net';
local devObsStreamInfoFunction = '/https-getObsStreamInfo';
local prodObsStreamInfoHost = 'get-obs-stream-info.dater.com';
local prodObsStreamInfoFunction = '/';
local defaultObsStreamFunction = prodObsStreamInfoFunction;
local p_user_id = ''
local p_obs_token = ''
local hotkeys = {
  htk_refresh = "Dater: Refresh Game",
  htk_hide_partner_video = "Dater: Hide Partner Video",
}
local hk = {}
local key_1 = '{"htk_1": [ { "key": "OBS_KEY_1" } ],'
local key_2 = '"htk_2": [ { "key": "OBS_KEY_2" } ]}'
local json_s = key_1 .. key_2
local default_hotkeys = {
  { id = 'htk_1', des = 'Button 1 ', callback = htk_1_cb },
  { id = 'htk_2', des = 'Button 2 ', callback = htk_2_cb },
}

obs = obslua

print("Starting Dater OBS Plugin...")

function script_description()
  return [[Get your current match stream and play it in VLC Source automatically]]
end

function script_properties()
  local props = obs.obs_properties_create()

  local vlc_player = obs.obs_properties_add_list(props, "vlc_source", "VLC Source", obs.OBS_COMBO_TYPE_EDITABLE,
    obs.OBS_COMBO_FORMAT_STRING)
  local sources = obs.obs_enum_sources()
  local daterEnvironment = obs.obs_properties_add_list(props, "dater_dev_env", "Environment", obs.OBS_COMBO_TYPE_EDITABLE
    , obs.OBS_COMBO_FORMAT_STRING)
  obs.obs_property_list_add_string(daterEnvironment, devEnvironment, devEnvironment)
  obs.obs_property_list_add_string(daterEnvironment, prodEnvironment, prodEnvironment)

  if sources ~= nil then
    for _, source in ipairs(sources) do
      source_id = obs.obs_source_get_unversioned_id(source)
      if source_id == "vlc_source" then
        local name = obs.obs_source_get_name(source)
        obs.obs_property_list_add_string(vlc_player, name, name)
      end
    end
  end

  obs.source_list_release(sources)

  obs.obs_properties_add_text(props, "user_id", "Dater userId", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_text(props, "obs_token", "Dater OBS Token", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_bool(props, "autostart", "Autostart playing")
  -- local apply_button = obs.obs_properties_add_button(props, "apply", "Apply", set_vlc_player_settings)
  local start_button = obs.obs_properties_add_button(props, "startDater", "Start", get_obs_stream_info)

  obs.obs_property_set_modified_callback(vlc_player, settings_modified)
  obs.obs_property_set_modified_callback(daterEnvironment, settings_modified)
  -- obs.obs_property_set_modified_callback(apply_button, settings_modified)

  settings_modified(props, nil, settings_)

  return props
end

local function isNotEmpty(textString)
  return textString ~= nil and textString ~= ''
end

function settings_modified(props, prop, settings)
  if settings ~= nil then
    settings = settings_
  end

  -- local p_vlc_source = obs.obs_properties_get(props, "vlc_source")
  p_user_id = obs.obs_data_get_string(settings, "user_id")
  p_obs_token = obs.obs_data_get_string(settings, "obs_token")
  local p_autostart = obs.obs_data_get_bool(settings, "autostart")
  local vlc_source_name = obs.obs_data_get_string(settings, "vlc_source")

  activeDevEnironment = obs.obs_data_get_string(settings, "dater_dev_env")

  print('----------------------');
  print('Settings changed..');
  print('Dev Enviroment: ' .. activeDevEnironment);
  print('Autostart: ' .. tostring(p_autostart));

  if vlc_source_name == nil then
    return
  end

  set_vlc_player_settings()

  print("VLC source: " .. vlc_source_name);

  if isNotEmpty(p_user_id) then
    print('Dater User Id: ' .. p_user_id);
  end

  if isNotEmpty(p_obs_token) then
    print('Dater OBS Token: ' .. p_obs_token);
  end
  settings_ = settings

  return true
end

function script_defaults(settings)
  obs.obs_data_set_default_string(settings, "vlc_source", "-----")
  obs.obs_data_set_default_int(settings, "start_in_secs", 0)
  obs.obs_data_set_default_string(settings, "dater_dev_env", activeDevEnironment)
end

function script_load(settings)
  local sh = obs.obs_get_signal_handler()
  obs.signal_handler_connect(sh, "source_show", source_activated)
  obs.signal_handler_connect(sh, "source_hide", source_deactivated)

  obs.obs_frontend_add_event_callback(on_event)

  settings_ = settings

  regiser_hot_keys(settings)
  script_update(settings)
end

function script_update(settings)
  source_name = obs.obs_data_get_string(settings, "vlc_source")
  video_id = obs.obs_data_get_string(settings, "user_id")
end

function set_vlc_player_settings(partnerStreamUrl)
  local vlc_source = obs.obs_get_source_by_name(source_name)

  if vlc_source ~= nil then
    local vlc_settings = obs.obs_data_create()
    obs.obs_data_set_bool(vlc_settings, "always_play", true)

    -- "playlist"
    local array = obs.obs_data_array_create()
    local item = obs.obs_data_create()
    obs.obs_data_set_string(item, "value", partnerStreamUrl)
    obs.obs_data_array_push_back(array, item)
    obs.obs_data_set_array(vlc_settings, "playlist", array)

    -- updating will automatically cause the source to
    -- refresh if the source is currently active

    obs.obs_data_release(item)
    obs.obs_data_array_release(array)
    obs.obs_source_update(vlc_source, vlc_settings)
    obs.obs_data_release(vlc_settings)
    obs.obs_source_release(vlc_source)
  end
end

function set_text_source_settings(text_source_name, text)
  print("Updating text source with: " .. text)

  local text_source = obs.obs_get_source_by_name(text_source_name)

  if text_source ~= nil then
    local text_settings = obs.obs_data_create()
    obs.obs_data_set_string(text_settings, "text", text)

    -- local item = obs.obs_data_create()
    -- obs.obs_data_set_string(item, "value", coinsNumber)

    -- updating will automatically cause the source to
    -- refresh if the source is currently active

    -- obs.obs_data_release(item)
    obs.obs_source_update(text_source, text_settings)
    obs.obs_data_release(text_settings)
    obs.obs_source_release(text_source)
  end
end

function get_obs_stream_info()
  local obsFunction;
  local host;
  local parseResult = ''

  if activeDevEnironment == prodEnvironment then
    obsFunction = prodObsStreamInfoFunction
    host = prodObsStreamInfoHost
  elseif activeDevEnironment == devEnvironment then
    obsFunction = devObsStreamInfoFunction
    host = devObsStreamInfoHost
  else
    obsFunction = defaultObsStreamFunction
    host = prodObsStreamInfoHost
  end

  local getUrlWithParams = obsFunction .. '?userId=' .. p_user_id.. '&obsAccessToken='..p_obs_token;
  local socket = assert(socket.create("inet", "stream", "tcp"))

  assert(socket:set_blocking(false))
  assert(socket:connect(host, "http"))

  print("Request OBS function: http://" .. host .. getUrlWithParams .."\n\n");

  while true do
    if socket:is_connected() then
      assert(socket:send(
        "GET /" .. getUrlWithParams .. " HTTP/1.1\r\n" ..
        "Host: " .. host .. "\r\n" ..
        "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:64.0) Gecko/20100101 Firefox/64.0\r\n" ..
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n" ..
        "Accept-Language: nb,nb-NO;q=0.9,en;q=0.8,no-NO;q=0.6,no;q=0.5,nn-NO;q=0.4,nn;q=0.3,en-US;q=0.1\r\n" ..
        --"Accept-Encoding: gzip, deflate\r\n"..
        "DNT: 1\r\n" ..
        "Connection: keep-alive\r\n" ..
        "Upgrade-Insecure-Requests: 1\r\n" ..
        "\r\n"
      ))

      local total_length

      while true do
        local chunk, err = socket:receive()

        if chunk then
          parseResult = parseResult .. chunk

          if not total_length then
            total_length = tonumber(parseResult:match("Content%-Length: (%d+)"))
          end

                    if #parseResult >= total_length then
            parseHttpGetResult(parseResult)
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
end

function parseHttpGetResult(parseResultRaw)
  print(parseResultRaw)
  local parseResultJsonString = parseResultRaw:match("{\"data\":(.+),\"status\":200}") or 'empty'

  local jsonResponse = json.decode(parseResultJsonString);

  -- local myCoinsBalance = tonumber(parseResultRaw:match("\"myInfo\":{\"coinsBalance\":(%d+),\"")) or 0
  -- local myNumberOfCalls = tonumber(parseResultRaw:match("numberOfCalls\":(%d+),\"")) or 0
  -- local partnerStream = parseResultRaw:match("myself\":\"(%S+)\"},") or nil
  -- local myStream = parseResultRaw:match("myself\":\"(%S+)\",\"partner") or nil

  print("myCoinsBalance: " .. jsonResponse.myInfo.coinsBalance)
  print("myNumberOfCalls: " .. jsonResponse.myInfo.numberOfCalls)
  print("subscribers: " .. jsonResponse.myInfo.subscribers)

  if jsonResponse.myInfo.coinsBalance ~= nil then
    set_text_source_settings('coins', 'Coins: '..jsonResponse.myInfo.coinsBalance)
  end

  if jsonResponse.myInfo.avatarInfo.avatarState.energyCurrent ~= nil then
    set_text_source_settings('energy', 'Energy: ' .. jsonResponse.myInfo.avatarInfo.avatarState.energyCurrent)
  end

  if jsonResponse.myInfo.avatarInfo.avatarState.energyAvailable ~= nil then
    set_text_source_settings('total_energy', 'Max Energy: ' .. jsonResponse.myInfo.avatarInfo.avatarState.energyAvailable)
  end

  if jsonResponse.currentReward ~= nil then
    set_text_source_settings('reward', jsonResponse.currentReward)
  end

  if jsonResponse.myInfo.numberOfCalls ~= nil then
    set_text_source_settings('video_calls', 'Video Calls: ' .. jsonResponse.myInfo.numberOfCalls)
  end

  if jsonResponse.myInfo.totalCoinsEverReceived ~= nil then
    set_text_source_settings('total_coins', 'Total Coins: ' .. jsonResponse.myInfo.totalCoinsEverReceived)
  end

  if jsonResponse.partner ~= nil then
    set_text_source_settings('partner_info', jsonResponse.partner.name .. ', ' .. jsonResponse.partner.age)
  end

  if jsonResponse.currentStreamUrls.partner ~= nil then
    print("partnerStream: " .. jsonResponse.currentStreamUrls.partner)
    set_vlc_player_settings(jsonResponse.currentStreamUrls.partner)
  end

  -- if myStream ~= nil then
  --   print("myStream: " .. myStream)
  --   set_vlc_player_settings(myStream)
  -- end

  print("\nDone!\n");
end

function hotkey_mapping(hotkey)
  if hotkey == "htk_stop" then
    print('Стоп')
  elseif hotkey == "htk_start" then
    print('Старт')
  end
end

function htk_1_cb(pressed)
  print('Refresh game pressed')

  if pressed then
    print('Refresh game pressed')
  end
end

function htk_2_cb(pressed)
  if pressed then
    print('Hide video partner pressed')
  end
end

function regiser_hot_keys(settings)
    for k, v in pairs(hotkeys) do
    hk[k] = obs.obs_hotkey_register_frontend(k, v, function(pressed)
      if pressed then 
        hotkey_mapping(k)
      end
    end)
    a = obs.obs_data_get_array(settings, k)
    obs.obs_hotkey_load(hk[k], a)
    obs.obs_data_array_release(a)
  end

  s = obs.obs_data_create_from_json(json_s)
  for _,v in pairs(default_hotkeys) do
    a = obs.obs_data_get_array(s,v.id)
    h = obs.obs_hotkey_register_frontend(v.id,v.des,v.callback)
    obs.obs_hotkey_load(h,a)
    obs.obs_data_array_release(a)
  end
  obs.obs_data_release(s)
end

function script_save(settings)
  for k, v in pairs(hotkeys) do
    a = obs.obs_hotkey_save(hk[k])
    obs.obs_data_set_array(settings, k, a)
    obs.obs_data_array_release(a)
  end
end
