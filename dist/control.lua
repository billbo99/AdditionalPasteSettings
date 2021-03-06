local Smarts = require("smarts")

local function on_init()
    global.event_backup = global.event_backup or {}
end

local function on_configuration_changed()
end

-- Event register

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)

script.on_event("additional-paste-settings-hotkey", Smarts.on_hotkey_pressed)

script.on_event(defines.events.on_pre_entity_settings_pasted, Smarts.on_vanilla_pre_paste)
script.on_event(defines.events.on_entity_settings_pasted, Smarts.on_vanilla_paste)
