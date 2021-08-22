obs           = obslua

-- used lyrics.lua for a bunch of logic. Still needs a ton of work to actually make usable

-- variables set by user (via pref_ variables)
obs_text_object		= "" 	-- OBS text object that we are manipulating
announcements_file 	= "" 	-- Text file on the local system
visible_lines 		= 1 	-- Number of lines to count as a single announcement
loop_timer_seconds 	= 10	-- How long each announcement is shown before going to the next one

-- variables used by script, generated or computed and not user-configured
current_announcement_index = 1	-- Global script variable to keep track of which announcement we are currently showing - 0 indexed
array_announcements 	= {}	-- Internal array of announcement strings
activated     		= false	-- @TODO figure out if we need this

-- Function to show the announcement @TODO actually show the announcement
function set_announcement_text()
	local text = array_announcements[current_announcement_index]
	local source = obs.obs_get_source_by_name(obs_text_object)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

-- check file exists
function file_exists(file)
	local f = io.open(file, "rb")
	if f then 
		f:close()
	end
	return f ~= nil
end

-- load all announcements from a file into announcement list
function load_announcements(file)
	if not file_exists(file) then
		array_announcements = {}
		return
	end
	array_announcements = {}
	local line_counter = 0
	local announcement_string = ""
	local announcement_contains_data = false
	for line in io.lines(file) do
		if ((line_counter % visible_lines) == 0) then
			-- first line of the announcement
			announcement_string = line
		else
			-- not first line
			announcement_string = announcement_string .. "\n" .. line
		end
		if (line ~= '') then
			-- keep track of the announcement. if it ends up all being blank lines, exclude it altogether.
			-- (can't just check the string after concating it, since it will have newline characters)
			announcement_contains_data = true
		end

		-- check if we've read enough lines for one announcement
		if (((line_counter + 1) % visible_lines) == 0) then
			-- next line to be read will be the start of a new announcement. Add the current string to our array and clear the string.
			if (announcement_contains_data) then
				array_announcements[#array_announcements + 1] = announcement_string
			end
			announcement_string = ""
			announcement_contains_data = false
		end
		line_counter = line_counter + 1
	end
	if (announcement_contains_data) then
		-- if we reached the end, but there's still text in the string, it means the last annoucement wasn't long enough (lines_per_announcement > 1). add it anyway instead of discarding it.
		array_announcements[#array_announcements + 1] = announcement_string
	end
end

-- increments the current announcement index. If it's equal to the length of the array, reset it to 1 (Lua arrays are 1-indexed by convention)
function next_announcement()
	if current_announcement_index < #array_announcements then
		current_announcement_index = current_announcement_index + 1
	else
		current_announcement_index = 1
	end
	set_announcement_text()
end

-- This function runs every few seconds (depends on user preference).
-- It also reloads the announcement file, so that if it gets updated, it will constantly have the new values.
-- Otherwise, the user would have to click a reset button or change a preference to refresh the cached values.
function announcement_timer_callback()
	load_announcements(announcements_file)
	next_announcement()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		set_announcement_text()
		obs.timer_add(announcement_timer_callback, loop_timer_seconds*1000)
	else
		obs.timer_remove(announcement_timer_callback)
	end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "pref_obs_text_object")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == obs_text_object) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, true)
end

function reset(pressed)
	if not pressed then
		return
	end

	activate(false)
	local source = obs.obs_get_source_by_name(obs_text_object)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	reset(true)
	return false
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()

	-- local p = obs.obs_properties_add_list(props, "pref_obs_text_object", "OBS Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local p = obs.obs_properties_add_list(props, "pref_obs_text_object", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)



	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				-- name = name:gsub('%W','')
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end

	obs.source_list_release(sources)

	obs.obs_properties_add_path(props, "pref_announcements_file", "Text file with announcements", obs.OBS_PATH_FILE, "Text File (*.txt)", "")
	obs.obs_properties_add_int(props, "pref_visible_lines", "Lines per single announcement", 1, 10, 1)	
	obs.obs_properties_add_int(props, "pref_loop_timer_seconds", "Seconds per announcement", 1, 999, 1)	

	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Sets a text source to act as an announcement line changer, showing each announcement for a set time before switching to the next one.\n\nMade by Stephen Schrauger."
end

-- A function named script_update will be called when settings are changed
-- Update global script variables when OBS settings are changed by the user
function script_update(settings)
	activate(false)

	obs_text_object 	= obs.obs_data_get_string(settings, 	"pref_obs_text_object")
	announcements_file 	= obs.obs_data_get_string(settings, 	"pref_announcements_file")
	visible_lines 		= obs.obs_data_get_int(settings, 	"pref_visible_lines")
	loop_timer_seconds 	= obs.obs_data_get_int(settings, 	"pref_loop_timer_seconds")

	load_announcements(announcements_file)
	set_announcement_text()
	reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)

	obs.obs_data_set_default_string(settings, 	"pref_obs_text_object", 	""	)
	obs.obs_data_set_default_string(settings, 	"pref_announcements_file", 	""	)
	obs.obs_data_set_default_int(settings, 		"pref_visible_lines", 		1	)
	obs.obs_data_set_default_int(settings, 		"pref_loop_timer_seconds", 	10	)

end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

end
