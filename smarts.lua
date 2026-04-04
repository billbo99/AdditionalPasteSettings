require('util')

local lib = require('lib')
local config = require('config')
local Smarts = {} ---@class Smarts

--------------------------------------------------------------------------------------------------------------
----------  Local Helper functions

--------------------------------------------------------------------------------------------------------------
-- Classes

---@class ItemCycle
---@field name string
---@field type string

---@class EntityData
---@field cycle ItemCycle[]
---@field cycle_index int


--------------------------------------------------------------------------------------------------------------
----------  Local cycle functions

-----  Container cycle
---@param entity LuaEntity
---@return ItemCycle[]
local function container_cycle(entity)
    local cycle = {}
    if entity and entity.valid and entity.get_inventory(defines.inventory.chest) then
        -- local inventory = lib.get_keys(entity.get_inventory(defines.inventory.chest).get_contents())
        for _, v in pairs(entity.get_inventory(defines.inventory.chest).get_contents()) do
            table.insert(cycle, { name = v.name, type = "item", quality = v.quality })
        end
    end
    return cycle
end

-- -----  Decider/Arithmetic combinator cycle
-- ---@param entity LuaEntity
-- ---@return ItemCycle[]
-- local function decider_arithmetic_combinator_cycle(entity)
--     local cycle = {}
--     if entity and entity.valid then
--         local cb = entity.get_control_behavior() ---@cast cb LuaCombinatorControlBehavior
--         if cb and cb.signals_last_tick then
--             local signals = cb.signals_last_tick
--             for _, v in pairs(signals) do
--                 table.insert(cycle, v.signal)
--             end
--         end
--     end
--     return cycle
-- end

-- -----  DisplayPlate current sprite
-- ---@param entity LuaEntity
-- ---@return ItemCycle[]
-- local function simple_entity_with_owner_cycle(entity)
--     local remote_interface
--     if game.active_mods["IndustrialDisplayPlates"] then remote_interface = "IndustrialDisplayPlates" end
--     if game.active_mods["DisplayPlates"] then remote_interface = "DisplayPlates" end

--     local interfaces = remote.interfaces[remote_interface]
--     if (not interfaces.get_sprite) and (not interfaces.set_sprite) then return {} end

--     local rv = remote.call(remote_interface, "get_sprite", { entity = entity })
--     if (not rv) then return {} end

--     local cycle = { { type = rv.spritetype, name = rv.spritename } }
--     return cycle
-- end

-----  Assembly Machine cycle
---@param entity LuaEntity
---@return ItemCycle[]
local function assembly_cycle(entity)
    local cycle = {}

    if entity and entity.valid and entity.get_recipe() then
        local recipe, quality = entity.get_recipe()
        for _, v in pairs(recipe.products) do
            v.quality = quality.name
            table.insert(cycle, v)
        end
        for _, v in pairs(recipe.ingredients) do
            v.quality = quality.name
            table.insert(cycle, v)
        end
    end

    return cycle
end

---@param ingredients table[]
---@param qname string
---@return string
local function build_ltn_all_inputs_station_name(ingredients, qname)
    if not ingredients or #ingredients == 0 then return "" end
    local icons = {}
    local names = {}
    for _, v in ipairs(ingredients) do
        local item = { name = v.name, type = v.type, quality = qname }
        table.insert(icons, lib.parse_signal_to_rich_text(item))
        local nm
        if config["use_Babelfish"] then
            nm = lib.find_name_in_babelfish_dictonary(item.name, item.type)
        else
            nm = item.name
        end
        table.insert(names, nm)
    end
    local fmt = config["station_name_ltn_all_inputs"] or "LTN __1__"
    return lib.parse_string(fmt, { table.concat(icons, " "), table.concat(names, ", ") })
end

--- Train stop naming from assembler: each product → Load then Unload; optional LTN bundle of all inputs; each ingredient → Unload only.
---@param assembler LuaEntity
---@param player LuaPlayer|nil
---@return { item?: ItemCycle, use_load_template?: boolean, custom_station_name?: string }[]
local function assembler_train_schedule_from_recipe(assembler, player)
    local recipe, quality = assembler.get_recipe()
    if not recipe then return {} end
    local qname = quality and quality.name or "normal"
    local schedule = {}

    for _, v in ipairs(recipe.products) do
        local item = { name = v.name, type = v.type, quality = qname }
        table.insert(schedule, { item = item, use_load_template = true })
        table.insert(schedule, { item = item, use_load_template = false })
    end

    local ltn_bundle = player
        and player.valid
        and settings.get_player_settings(player)["additional-paste-settings-options-train-stop-assembler-ltn-inputs-bundle-step"].value
    if ltn_bundle and recipe.ingredients and #recipe.ingredients > 0 then
        local bundled = build_ltn_all_inputs_station_name(recipe.ingredients, qname)
        if bundled ~= "" then
            table.insert(schedule, { custom_station_name = bundled })
        end
    end

    for _, v in ipairs(recipe.ingredients) do
        local item = { name = v.name, type = v.type, quality = qname }
        table.insert(schedule, { item = item, use_load_template = false })
    end

    return schedule
end

--- Loaders use ItemFilter for items only; recipe fluids are not item prototypes.
---@param cycle ItemCycle[]
---@return ItemCycle[]
local function cycle_for_loader_filters(cycle)
    if not cycle then return {} end
    local filtered = {}
    for _, v in ipairs(cycle) do
        if v.name and v.type ~= "fluid" and prototypes.item[v.name] then
            table.insert(filtered, v)
        end
    end
    return filtered
end

-- -----  Constant Combinator cycle
-- ---@param entity LuaEntity
-- ---@return ItemCycle[]
-- local function constant_combinator_cycle(entity)
--     local cycle = {}

--     if entity and entity.valid then
--         local cb = entity.get_control_behavior() ---@cast cb LuaConstantCombinatorControlBehavior
--         if cb and cb.enabled then
--             local signals = cb.parameters
--             for _, v in pairs(signals) do
--                 if v.signal.name then
--                     table.insert(cycle, v.signal)
--                 end
--             end
--         end
--     end

--     return cycle
-- end

--------------------------------------------------------------------------------------------------------------
----------  Local rename functions

-- ---@param display_panel LuaEntity
-- ---@param cycle ItemCycle[]
-- local function update_sa_display_panel(display_panel, cycle)
--     if display_panel.name ~= "display-panel" then return end

--     -- If the destination is a SE landing pad use remote interface to rename the pad and show a flying text
--     storage.entity_data[display_panel.unit_number] = storage.entity_data[display_panel.unit_number] or {}

--     -- Check if the global dict tracking the entities being changed needs to be reset due to a new inventory
--     local entity = storage.entity_data[display_panel.unit_number]
--     if entity == nil or entity.cycle == nil or (not table.compare(cycle, entity.cycle)) then
--         entity = entity or {}
--         entity.cycle = cycle
--         entity.cycle_index = 1
--     end

--     local item = entity.cycle[entity.cycle_index]
--     if (not item) then return end

--     local item_name
--     if config['use_Babelfish'] then
--         item_name = lib.find_name_in_babelfish_dictonary(item.name, item.type)
--     else
--         item_name = item.name
--     end

--     -- Get the name of the cargo rocket pad following the naming standard in the "MAP SETTINGS"
--     local name = lib.parse_signal_to_rich_text(item)
--     entity.cycle_index = entity.cycle_index + 1
--     if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

--     ---@param cb LuaDisplayPanelControlBehavior
--     local cb = display_panel.get_or_create_control_behavior()
--     if cb then
--         local orig_message = cb.get_message(1)
--         orig_message.icon = { name = item.name }
--         orig_message.text = item_name
--         cb.set_message(1, orig_message)
--     end

--     -- Grab the current name and if the new name is different use the remote interface to change the name of the landing pad
--     game.print(name)
-- end

-- ---@param landing_pad_entity LuaEntity
-- ---@param cycle ItemCycle[]
-- local function update_se_landing_pad_name(landing_pad_entity, cycle)
--     if landing_pad_entity.name ~= "se-rocket-landing-pad" then return end

--     -- If the destination is a SE landing pad use remote interface to rename the pad and show a flying text
--     storage.entity_data[landing_pad_entity.unit_number] = storage.entity_data[landing_pad_entity.unit_number] or {}

--     -- Check if the global dict tracking the entities being changed needs to be reset due to a new inventory
--     local entity = storage.entity_data[landing_pad_entity.unit_number]
--     if entity == nil or entity.cycle == nil or (not table.compare(cycle, entity.cycle)) then
--         entity = entity or {}
--         entity.cycle = cycle
--         entity.cycle_index = 1
--     end

--     local item = entity.cycle[entity.cycle_index]
--     if (not item) then return end

--     local item_name
--     if config['use_Babelfish'] then
--         item_name = lib.find_name_in_babelfish_dictonary(item.name, item.type)
--     else
--         item_name = item.name
--     end

--     -- Get the name of the cargo rocket pad following the naming standard in the "MAP SETTINGS"
--     local name = lib.parse_string(config['se-rocket-landing-pad-name'], { lib.parse_signal_to_rich_text(item), item_name })
--     entity.cycle_index = entity.cycle_index + 1
--     if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

--     -- Grab the current name and if the new name is different use the remote interface to change the name of the landing pad
--     local current_name = remote.call("space-exploration", "get_landing_pad_name",
--         { unit_number = landing_pad_entity.unit_number })
--     if current_name ~= name then
--         landing_pad_entity.surface.create_entity { name = "flying-text", position = landing_pad_entity.position, text = name, color = lib.colors.white }
--         remote.call("space-exploration", "set_landing_pad_name", { unit_number = landing_pad_entity.unit_number, name = name })
--     end
-- end

-- ---@param display_plate LuaEntity
-- ---@param cycle ItemCycle[]
-- local function update_simple_entity_with_owner(display_plate, cycle)
--     local remote_interface
--     if game.active_mods["IndustrialDisplayPlates"] then remote_interface = "IndustrialDisplayPlates" end
--     if game.active_mods["DisplayPlates"] then remote_interface = "DisplayPlates" end
--     if game.active_mods["Display_Plates"] then remote_interface = "Display_Plates" end

--     if not remote_interface then return end
--     if not remote.interfaces[remote_interface] then return end

--     local interfaces = remote.interfaces[remote_interface]
--     if (not interfaces.get_sprite) and (not interfaces.set_sprite) then return end

--     local rv = remote.call(remote_interface, "get_sprite", { entity = display_plate })
--     if (not rv) then return end

--     storage.entity_data[display_plate.unit_number] = storage.entity_data[display_plate.unit_number] or {}
--     local entity = storage.entity_data[display_plate.unit_number]

--     if entity == nil or entity.cycle == nil or not table.compare(cycle, entity.cycle) then
--         entity = entity or {}
--         entity.cycle = cycle
--         entity.cycle_index = 1
--     end

--     if entity.cycle[entity.cycle_index].type == "virtual" then
--         entity.cycle[entity.cycle_index].type = "virtual-signal"
--     end
--     local new_sprite = entity.cycle[entity.cycle_index].type .. "/" .. entity.cycle[entity.cycle_index].name

--     local msg = lib.parse_signal_to_rich_text(entity.cycle[entity.cycle_index]) .. " " .. entity.cycle[entity.cycle_index].name
--     display_plate.surface.create_entity { name = "flying-text", position = display_plate.position, text = msg, color = lib.colors.white }
--     remote.call(remote_interface, "set_sprite", { entity = display_plate, sprite = new_sprite })

--     entity.cycle_index = entity.cycle_index + 1
--     if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end
-- end

----------

---comment
---@param mtype any
---@param multiplier double
---@param stack any
---@param previous_value int
---@param recipe LuaRecipe
---@param speed any
---@param additive any
---@param special? float
---@return int
local function update_stack(mtype, multiplier, stack, previous_value, recipe, speed, additive, special)
    if mtype == "additional-paste-settings-per-stack-size" then
        if additive and previous_value ~= nil then
            if special then
                return previous_value * special
            else
                if prototypes.item[stack.name] and prototypes.item[stack.name].stack_size then
                    return math.floor(previous_value + (prototypes.item[stack.name].stack_size * multiplier))
                else
                    return 0
                end
            end
        else
            if special then
                if prototypes.item[stack.name] and prototypes.item[stack.name].stack_size then
                    return math.floor(prototypes.item[stack.name].stack_size * special)
                else
                    return 0
                end
            else
                if prototypes.item[stack.name] and prototypes.item[stack.name].stack_size then
                    return math.floor(prototypes.item[stack.name].stack_size * multiplier)
                else
                    return 0
                end
            end
        end
    elseif mtype == "additional-paste-settings-per-recipe-size" then
        local amount = 0
        if recipe then
            for i = 1, #recipe.ingredients do
                if recipe.ingredients[i].name == stack.name then
                    amount = recipe.ingredients[i].amount
                    break
                end
            end
            for i = 1, #recipe.products do
                if recipe.products[i].name == stack.name then
                    if recipe.products[i].amount then
                        amount = recipe.products[i].amount
                    else
                        amount = recipe.products[i].amount_max
                    end
                    break
                end
            end
        end
        if additive and previous_value ~= nil then
            return math.floor(previous_value + amount * multiplier)
        else
            return math.floor(amount * multiplier)
        end
    elseif mtype == "additional-paste-settings-per-time-size" then
        local amount = 0
        if recipe then
            for i = 1, #recipe.ingredients do
                if recipe.ingredients[i].name == stack.name then
                    amount = recipe.ingredients[i].amount
                    break
                end
            end
            for i = 1, #recipe.products do
                if recipe.products[i].name == stack.name then
                    if recipe.products[i].amount then
                        amount = recipe.products[i].amount
                    else
                        amount = recipe.products[i].amount_max
                    end
                    break
                end
            end
            if additive and previous_value ~= nil then
                return math.ceil(previous_value + amount * multiplier * speed / recipe.energy)
            else
                return math.ceil(amount * multiplier * speed / recipe.energy)
            end
        end
    else
        error "error"
    end
    return 0
end

function Smarts.FindAvailableLogisticsSection(obj)
    if obj and obj.valid and obj.get_requester_point() then
        local requester_point = obj.get_requester_point()
        if requester_point.enabled then
            for _, section in pairs(requester_point.sections) do
                if section.type == defines.logistic_section_type.manual then
                    return section
                end
            end
        end
    end
    return nil
end

function Smarts.EventBackupKey(src, dst)
    local key = {}
    key[1] = src.surface.name
    key[2] = src.position.x
    key[3] = src.position.y

    key[4] = dst.surface.name
    key[5] = dst.position.x
    key[6] = dst.position.y

    key_str = table.concat(key, "-")
    return key_str
end

function Smarts.SetEventBackup(src, dst, value)
    local key_str = Smarts.EventBackupKey(src, dst)
    storage.event_backup[key_str] = value
end

function Smarts.GetEventBackup(src, dst)
    local key_str = Smarts.EventBackupKey(src, dst)
    return storage.event_backup[key_str]
end

function Smarts.CopyMetric(obj, metric)
    local status, err = pcall(function()
        if obj[metric] ~= nil then
            return obj[metric]
        else
            return nil
        end
    end)
    if status then return err else return nil end
end

function Smarts.CopyControlBehavior(obj)
    local ctrl = {}

    ctrl.read_contents = Smarts.CopyMetric(obj, 'read_contents')
    ctrl.read_contents_mode = Smarts.CopyMetric(obj, 'read_contents_mode')
    ctrl.circuit_read_contents = Smarts.CopyMetric(obj, 'circuit_read_contents')
    ctrl.circuit_read_ingredients = Smarts.CopyMetric(obj, 'circuit_read_ingredients')
    ctrl.circuit_read_recipe_finished = Smarts.CopyMetric(obj, 'circuit_read_recipe_finished')
    ctrl.circuit_read_working = Smarts.CopyMetric(obj, 'circuit_read_working')
    ctrl.circuit_set_recipe = Smarts.CopyMetric(obj, 'circuit_set_recipe')
    ctrl.circuit_condition = Smarts.CopyMetric(obj, 'circuit_condition')
    ctrl.circuit_enable_disable = Smarts.CopyMetric(obj, 'circuit_enable_disable')
    ctrl.connect_to_logistic_network = Smarts.CopyMetric(obj, 'connect_to_logistic_network')
    ctrl.disabled = Smarts.CopyMetric(obj, 'disabled')
    ctrl.logistic_condition = Smarts.CopyMetric(obj, 'logistic_condition')

    return ctrl
end

--- Logical entity kind for paste routing; blueprint ghosts use `ghost_type`.
---@param ent LuaEntity
---@return string
local function entity_action_type(ent)
    if ent.valid and ent.type == "entity-ghost" and ent.ghost_type then
        return ent.ghost_type
    end
    return ent.type
end

--- Prototype of built entity; for `entity-ghost`, the inner ghost target.
---@param ent LuaEntity
local function entity_effective_prototype(ent)
    if ent.type == "entity-ghost" and ent.ghost_prototype then
        return ent.ghost_prototype
    end
    return ent.prototype
end

function Smarts.clear_inserter_settings(from, to, player, special)
    local clear_inserter_flag = settings.get_player_settings(player)["additional-paste-settings-paste-clear-inserter-filter-on-paste-over"].value
    if from == to and clear_inserter_flag then
        local ctrl = to.get_or_create_control_behavior()
        -- Disable/clear circuit smarts
        ctrl.circuit_enable_disable = false
        ctrl.circuit_condition = nil

        -- Disable/clear logistic smarts
        ctrl.connect_to_logistic_network = false
        ctrl.logistic_condition = nil

        -- Clear filters
        from.use_filters = false
        for idx = 1, from.filter_slot_count do
            from.set_filter(idx, nil)
        end
        local ed = storage.entity_data[to.unit_number]
        if ed then
            ed.assembly_paste_key = nil
        end
    end
end

function Smarts.assembly_to_logistic_chest(from, to, player, special)
    -- this needs additional logic from events on_vanilla_pre_paste and on_vanilla_paste to correctly set the filter
    local to_proto = entity_effective_prototype(to)
    if to_proto.logistic_mode == "requester" or to_proto.logistic_mode == "buffer" then
        Smarts.SetEventBackup(from, to, { gamer = player.index, stacks = {} })
        -- storage.event_backup[from.position.x .. "-" .. from.position.y .. "-" .. to.position.x .. "-" .. to.position.y] = { gamer = player.index, stacks = {} }
    elseif to_proto.logistic_mode == "storage" then
        if from.get_recipe() ~= nil then
            local msg
            local recipe, quality = from.get_recipe()
            local proto = prototypes.item[recipe.name]
            if proto then
                to.storage_filter = { name = proto.name, quality = quality.name }
                msg = "Filter applied [img=item." .. from.get_recipe().name .. "]"
                if player then player.create_local_flying_text({ text = msg, position = to.position, color = lib.colors.white }) end
            else
                local products = from.get_recipe().products
                for _, product in pairs(products) do
                    if product.type and product.type == "item" then
                        proto = prototypes.item[product.name]
                        break
                    end
                end
                if proto then
                    to.storage_filter = { name = proto.name, quality = quality.name }
                    msg = "Filter applied [img=item." .. proto.name .. "]"
                    if player then player.create_local_flying_text({ text = msg, position = to.position, color = lib.colors.white }) end
                end
            end
        end
    end
end

---@param station LuaEntity
---@param player LuaPlayer|nil
local function rename_train_stop_scheduled(station, player)
    local entity = storage.entity_data[station.unit_number]
    if not entity or not entity.train_schedule or #entity.train_schedule == 0 then return end

    if not entity.train_step_index or entity.train_step_index < 1 then
        entity.train_step_index = 1
    end

    local step = entity.train_schedule[entity.train_step_index]
    if not step then return end

    local station_name
    if step.custom_station_name then
        station_name = step.custom_station_name
    elseif step.item then
        local item = step.item
        local item_name
        if config['use_Babelfish'] then
            item_name = lib.find_name_in_babelfish_dictonary(item.name, item.type)
        else
            item_name = item.name
        end
        if step.use_load_template then
            station_name = lib.parse_string(config['station_name_load'], { lib.parse_signal_to_rich_text(item), item_name })
        else
            station_name = lib.parse_string(config['station_name_unload'], { lib.parse_signal_to_rich_text(item), item_name })
        end
    else
        return
    end

    if station.backer_name ~= station_name then
        station.backer_name = station_name
        if player then player.create_local_flying_text({ text = station.backer_name, position = station.position, color = lib.colors.white }) end
    end

    entity.train_step_index = entity.train_step_index + 1
    if entity.train_step_index > #entity.train_schedule then
        entity.train_step_index = 1
    end
end

local function rename_train_stop(station, player)
    local entity = storage.entity_data[station.unit_number]
    if entity and entity.train_schedule and #entity.train_schedule > 0 then
        rename_train_stop_scheduled(station, player)
        return
    end

    local station_name
    if not entity or not entity.cycle or not entity.cycle[entity.cycle_index] then return end
    local item = entity.cycle[entity.cycle_index]

    if (not item) then return end

    local item_name
    if config['use_Babelfish'] then
        item_name = lib.find_name_in_babelfish_dictonary(item.name, item.type)
    else
        item_name = item.name
    end

    if entity.mode == "Load" then station_name = lib.parse_string(config['station_name_load'], { lib.parse_signal_to_rich_text(item), item_name }) end
    if entity.mode == "Unload" then station_name = lib.parse_string(config['station_name_unload'], { lib.parse_signal_to_rich_text(item), item_name }) end
    if entity.mode == "Unload" then entity.cycle_index = entity.cycle_index + 1 end
    if entity.mode == "Load" then entity.mode = "Unload" else entity.mode = "Load" end
    if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

    if station.backer_name ~= station_name then
        station.backer_name = station_name
        if player then player.create_local_flying_text({ text = station.backer_name, position = station.position, color = lib.colors.white }) end
    end
end

local function update_station(to, cycle, player)
    storage.entity_data[to.unit_number] = storage.entity_data[to.unit_number] or {}
    local entity = storage.entity_data[to.unit_number]

    if entity == nil or entity.cycle == nil or (not table.compare(cycle, entity.cycle)) then
        entity.mode = "Load"
        entity.cycle = cycle
        entity.cycle_index = 1
        entity.train_schedule = nil
        entity.train_step_index = nil
        entity.assembler_train_recipe_key = nil
    end

    rename_train_stop(to, player)
end

-- local function configure_decider_arithmetic_combinator(to, special)
--     local entity = storage.entity_data[to.unit_number]
--     local item = entity.cycle[entity.cycle_index]
--     if (not item) then return end

--     local ctrl = to.get_or_create_control_behavior()
--     local params = table.deepcopy(ctrl.parameters)
--     if special then
--         params.output_signal = { name = item.name, type = item.type }
--         msg = "Output condition set [img=item." .. item.name .. "]"
--     else
--         params.first_signal = { name = item.name, type = item.type }
--         msg = "First condition set [img=item." .. item.name .. "]"

--         -- Clear the output signal if invalid.
--         -- The output signal `each` (and `any`) is valid only if an input signal is `each` (and `any`) respectively.
--         if params.output_signal and (params.output_signal.name == "signal-any" or params.output_signal.name == "signal-each" and (not params.second_signal or params.output_signal.name ~= params.second_signal.name)) then
--             msg = msg .. " and output signal cleared"
--             params.output_signal = nil
--         end
--     end
--     ctrl.parameters = params

--     to.surface.create_entity { name = "flying-text", position = to.position, text = msg, color = lib.colors.white }

--     entity.cycle_index = entity.cycle_index + 1
--     if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end
-- end

-- local function update_decider_arithmetic_combinator(to, cycle, special)
--     storage.entity_data[to.unit_number] = storage.entity_data[to.unit_number] or {}
--     local entity = storage.entity_data[to.unit_number]

--     if entity == nil or entity.cycle == nil or (not table.compare(cycle, entity.cycle)) then
--         entity.cycle = cycle
--         entity.cycle_index = 1
--     end

--     configure_decider_arithmetic_combinator(to, special)
-- end

-- function Smarts.container_to_decider_arithmetic_combinator(from, to, player, special)
--     if special then special = true else special = false end
--     local cycle = container_cycle(from)
--     if #cycle > 0 then update_decider_arithmetic_combinator(to, cycle, special) end
-- end

-- function Smarts.assembling_to_decider_arithmetic_combinator(from, to, player, special)
--     if special then special = true else special = false end
--     local cycle = assembly_cycle(from)
--     if #cycle > 0 then update_decider_arithmetic_combinator(to, cycle, special) end
-- end

-- function Smarts.constant_combinator_to_decider_arithmetic_combinator(from, to, player, special)
--     if special then special = true else special = false end
--     local cycle = constant_combinator_cycle(from)
--     if #cycle > 0 then update_decider_arithmetic_combinator(to, cycle, special) end
-- end

-- function Smarts.constant_combinator_to_train_stop(from, to, player, special)
--     local cycle = constant_combinator_cycle(from)
--     if #cycle > 0 then update_station(to, cycle, player) end
-- end

-- function Smarts.decider_arithmetic_combinator_to_train_stop(from, to, player, special)
--     local cycle = decider_arithmetic_combinator_cycle(from)
--     if #cycle > 0 then update_station(to, cycle, player) end
-- end

-- function Smarts.decider_arithmetic_combinator_to_container(from, to, player, special)
--     local cycle = decider_arithmetic_combinator_cycle(from)
--     if #cycle == 0 then return end
--     update_se_landing_pad_name(to, cycle)
-- end

-- function Smarts.simple_entity_with_owner_to_container(from, to, player, special)
--     if to.name == "se-rocket-landing-pad" then
--         local cycle = simple_entity_with_owner_cycle(from)
--         if #cycle == 0 then return end
--         update_se_landing_pad_name(to, cycle)
--     end
-- end

-- function Smarts.constant_combinator_to_container(from, to, player, special)
--     if to.name == "se-rocket-landing-pad" then
--         local cycle = constant_combinator_cycle(from)
--         if #cycle > 0 then update_se_landing_pad_name(to, cycle) end
--     end
-- end

-- function Smarts.assembling_to_display_panel(from, to, player, special)
--     if to.name == "display-panel" then
--         local cycle = assembly_cycle(from)
--         if #cycle > 0 then
--             update_sa_display_panel(to, cycle)
--         end
--     end
-- end

-- function Smarts.assembly_to_container(from, to, player, special)
--     if to.name == "se-rocket-landing-pad" then
--         local cycle = assembly_cycle(from)
--         if #cycle > 0 then update_se_landing_pad_name(to, cycle) end
--     end
-- end

-- function Smarts.container_to_container(from, to, player, special)
--     if to.name == "se-rocket-landing-pad" then
--         local cycle = container_cycle(from)
--         update_se_landing_pad_name(to, cycle)
--     end
-- end

-- function Smarts.decider_arithmetic_combinator_to_simple_entity_with_owner(from, to, player, special)
--     local cycle = decider_arithmetic_combinator_cycle(from)
--     if #cycle > 0 then update_simple_entity_with_owner(to, cycle) end
-- end

-- function Smarts.constant_combinator_to_simple_entity_with_owner(from, to, player, special)
--     local cycle = constant_combinator_cycle(from)
--     if #cycle > 0 then update_simple_entity_with_owner(to, cycle) end
-- end

-- function Smarts.assembly_to_simple_entity_with_owner(from, to, player, special)
--     local cycle = assembly_cycle(from)
--     if #cycle > 0 then update_simple_entity_with_owner(to, cycle) end
-- end

-- function Smarts.container_to_simple_entity_with_owner(from, to, player, special)
--     local cycle = container_cycle(from)
--     if #cycle > 0 then update_simple_entity_with_owner(to, cycle) end
-- end

function Smarts.container_to_train_stop(from, to, player, special)
    local cycle = container_cycle(from)
    if #cycle > 0 then update_station(to, cycle, player) end
end

function Smarts.assembly_to_train_stop(from, to, player, special)
    if settings.get_player_settings(player)["additional-paste-settings-options-train-stop-assembler-products-load-unload-then-input-unloads"].value then
        local ltn_bundle = settings.get_player_settings(player)["additional-paste-settings-options-train-stop-assembler-ltn-inputs-bundle-step"].value
        local schedule = assembler_train_schedule_from_recipe(from, player)
        if #schedule == 0 then return end

        local recipe, quality = from.get_recipe()
        local recipe_key = recipe
            and (
                recipe.name
                .. ":"
                .. (quality and quality.name or "normal")
                .. ":ltnB:"
                .. (ltn_bundle and "1" or "0")
            )
            or ""

        storage.entity_data[to.unit_number] = storage.entity_data[to.unit_number] or {}
        local entity = storage.entity_data[to.unit_number]

        if entity.assembler_train_recipe_key ~= recipe_key then
            entity.train_schedule = schedule
            entity.train_step_index = 1
            entity.assembler_train_recipe_key = recipe_key
        elseif not entity.train_schedule or #entity.train_schedule == 0 then
            entity.train_schedule = schedule
            entity.train_step_index = 1
        end

        rename_train_stop(to, player)
    else
        local entity = storage.entity_data[to.unit_number]
        if entity then
            entity.train_schedule = nil
            entity.train_step_index = nil
            entity.assembler_train_recipe_key = nil
        end
        local cycle = assembly_cycle(from)
        if #cycle > 0 then update_station(to, cycle, player) end
    end
end

function Smarts.assembly_to_transport_belt(from, to, player, special)
    if (not settings.get_player_settings(player)["additional-paste-settings-paste-to-belt-enabled"].value) then
        return
    end

    local ctrl = to.get_or_create_control_behavior()
    local c1 = ctrl.get_circuit_network(defines.wire_connector_id.circuit_red)
    local c2 = ctrl.get_circuit_network(defines.wire_connector_id.circuit_green)

    local fromRecipe, fromQuality = from.get_recipe()

    if fromRecipe == nil then
        -- clear logistic
        if ctrl.connect_to_logistic_network then
            ctrl.logistic_condition = nil
            ctrl.connect_to_logistic_network = false
        end
        -- clear circuit
        if ctrl.circuit_enable_disable then
            ctrl.circuit_condition = nil
            ctrl.circuit_enable_disable = false
        end
    else
        local product = fromRecipe.products[1].name
        local item = prototypes.item[product]

        if item ~= nil then
            local comparator = settings.get_player_settings(player)["additional-paste-settings-options-comparator-value"].value
            local multiplier = settings.get_player_settings(player)["additional-paste-settings-options-transport_belt-multiplier-value"].value ---@cast multiplier double
            local mtype = settings.get_player_settings(player)["additional-paste-settings-options-transport_belt-multiplier-type"].value
            local additive = settings.get_player_settings(player)["additional-paste-settings-options-sumup"].value
            local amount = update_stack(mtype, multiplier, item, nil, fromRecipe, from.crafting_speed, additive, special)
            if c1 == nil and c2 == nil then
                if ctrl.connect_to_logistic_network and ctrl.logistic_condition["first_signal"]["name"] == product then
                    if ctrl.logistic_condition["constant"] ~= nil then
                        amount = update_stack(mtype, multiplier, item, ctrl.logistic_condition["constant"], fromRecipe, from.crafting_speed, additive, special)
                    end
                else
                    ctrl.connect_to_logistic_network = true
                end
                ctrl.logistic_condition = { comparator = comparator, first_signal = { type = "item", name = product }, constant = amount }
                storage.control_behaviour[to.unit_number] = Smarts.CopyControlBehavior(ctrl)
                local msg = "[img=item." .. product .. "] " .. comparator .. " " .. math.floor(amount)
                if player then player.create_local_flying_text({ text = msg, position = to.position, color = lib.colors.white }) end
            else
                if ctrl.circuit_enable_disable and ctrl.circuit_condition["first_signal"]["name"] == product then
                    if ctrl.circuit_condition["constant"] ~= nil then
                        amount = update_stack(mtype, multiplier, item, ctrl.circuit_condition["constant"], fromRecipe, from.crafting_speed, additive, special)
                    end
                else
                    ctrl.circuit_enable_disable = true
                end
                ctrl.circuit_condition = { comparator = comparator, first_signal = { type = "item", name = product }, constant = amount }
                storage.control_behaviour[to.unit_number] = Smarts.CopyControlBehavior(ctrl)
                local msg = "[img=item." .. product .. "] " .. comparator .. " " .. math.floor(amount)
                if player then player.create_local_flying_text({ text = msg, position = to.position, color = lib.colors.white }) end
            end
        end
    end
end

--- Preserve order, drop duplicate name+quality (for filling every loader filter from a recipe).
---@param cycle ItemCycle[]
---@return ItemCycle[]
local function dedupe_item_cycles_preserve_order(cycle)
    if not cycle then return {} end
    local seen = {}
    local out = {}
    for _, v in ipairs(cycle) do
        if v.name then
            local q = v.quality or "normal"
            local key = v.name .. "^" .. q
            if not seen[key] then
                seen[key] = true
                table.insert(out, v)
            end
        end
    end
    return out
end

---@param loader LuaEntity
---@param items ItemCycle[]
---@param player LuaPlayer|nil
local function apply_all_loader_filter_slots(loader, items, player)
    for idx = 1, loader.filter_slot_count do
        loader.set_filter(idx, nil)
    end
    local n = math.min(loader.filter_slot_count, #items)
    for idx = 1, n do
        local v = items[idx]
        loader.set_filter(idx, { name = v.name, quality = v.quality or "normal" })
    end
    if player and n > 0 then
        local msg = "Filters " .. n .. "/" .. loader.filter_slot_count
        player.create_local_flying_text({ text = msg, position = loader.position, color = lib.colors.white })
    end
end

--- Copy control behaviour fields that exist on both entities (pcall skips unsupported keys).
---@param from LuaEntity
---@param to LuaEntity
local function paste_control_behavior_between(from, to)
    local from_cb = from.get_or_create_control_behavior()
    local to_cb = to.get_or_create_control_behavior()
    local copied = Smarts.CopyControlBehavior(from_cb)
    for key, value in pairs(copied) do
        pcall(function()
            to_cb[key] = value
        end)
    end
end

--- Collect non-empty filters in slot order (compact gaps).
---@param entity LuaEntity
---@return { name: string, quality: string }[]
local function get_entity_filters_compact(entity)
    local filters = {}
    for idx = 1, entity.filter_slot_count do
        local f = entity.get_filter(idx)
        if f and f.name then
            table.insert(filters, { name = f.name, quality = f.quality or "normal" })
        end
    end
    return filters
end

---@param from LuaEntity
---@param to LuaEntity
---@param player LuaPlayer|nil
local function paste_filters_between_entities(from, to, player)
    for idx = 1, to.filter_slot_count do
        to.set_filter(idx, nil)
    end
    local list = get_entity_filters_compact(from)
    local n = math.min(to.filter_slot_count, #list)
    for idx = 1, n do
        local f = list[idx]
        to.set_filter(idx, { name = f.name, quality = f.quality })
    end
    if entity_action_type(to) == "inserter" then
        to.use_filters = n > 0
    end
    if player and n > 0 then
        player.create_local_flying_text({ text = "Filters " .. n .. "/" .. to.filter_slot_count, position = to.position, color = lib.colors.white })
    end
end

function Smarts.loader_to_inserter(from, to, player, special)
    if not from.valid or not to.valid then return end
    paste_control_behavior_between(from, to)
    paste_filters_between_entities(from, to, player)
end

function Smarts.inserter_to_loader(from, to, player, special)
    if not from.valid or not to.valid then return end
    paste_control_behavior_between(from, to)
    paste_filters_between_entities(from, to, player)
end

local function set_loader_filter(loader, player)
    local entity = storage.entity_data[loader.unit_number]
    if not entity then return end
    entity.cycle = cycle_for_loader_filters(entity.cycle)
    if #entity.cycle == 0 then return end
    if type(entity.cycle_index) ~= "number" or entity.cycle_index < 1 then
        entity.cycle_index = 1
    end
    if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

    local item = entity.cycle[entity.cycle_index]

    if (not item) then return end

    local item_name
    if config['use_Babelfish'] then
        item_name = lib.find_name_in_babelfish_dictonary(item.name, item.type)
    else
        item_name = item.name
    end

    for idx = 1, loader.filter_slot_count do
        loader.set_filter(idx, nil)
    end

    local filter = { name = item.name, quality = item.quality or "normal" }
    loader.set_filter(1, filter)
    entity.cycle_index = entity.cycle_index + 1
    if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

    local msg = "Apply filter " .. "[img=item." .. item.name .. "]"
    if player then player.create_local_flying_text({ text = msg, position = loader.position, color = lib.colors.white }) end
end

---@param inserter LuaEntity
---@param items ItemCycle[]
---@param player LuaPlayer|nil
local function apply_all_inserter_filter_slots(inserter, items, player)
    inserter.use_filters = false
    for idx = 1, inserter.filter_slot_count do
        inserter.set_filter(idx, nil)
    end
    local n = math.min(inserter.filter_slot_count, #items)
    for idx = 1, n do
        local v = items[idx]
        inserter.set_filter(idx, { name = v.name, quality = v.quality or "normal" })
    end
    if n > 0 then
        inserter.use_filters = true
    end
    if player and n > 0 then
        player.create_local_flying_text({ text = "Filters " .. n .. "/" .. inserter.filter_slot_count, position = inserter.position, color = lib.colors.white })
    end
end

--- Rotate single inserter filter (slot 1), same pattern as set_loader_filter.
---@param inserter LuaEntity
---@param player LuaPlayer|nil
local function set_inserter_cycle_filter(inserter, player)
    local entity = storage.entity_data[inserter.unit_number]
    if not entity then return end
    entity.cycle = cycle_for_loader_filters(entity.cycle)
    if #entity.cycle == 0 then return end
    if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

    local item = entity.cycle[entity.cycle_index]
    if not item then return end

    inserter.use_filters = true
    for idx = 1, inserter.filter_slot_count do
        inserter.set_filter(idx, nil)
    end
    inserter.set_filter(1, { name = item.name, quality = item.quality or "normal" })
    entity.cycle_index = entity.cycle_index + 1
    if entity.cycle_index > #entity.cycle then entity.cycle_index = 1 end

    local msg = "Apply filter " .. "[img=item." .. item.name .. "]"
    if player then player.create_local_flying_text({ text = msg, position = inserter.position, color = lib.colors.white }) end
end

local function update_loader(to, cycle, player)
    cycle = cycle_for_loader_filters(cycle)
    if #cycle == 0 then return end

    storage.entity_data[to.unit_number] = storage.entity_data[to.unit_number] or {}
    local entity = storage.entity_data[to.unit_number]

    if entity == nil or entity.cycle == nil or (not table.compare(cycle, entity.cycle)) then
        entity.cycle = cycle
        entity.cycle_index = 1
        entity.assembly_paste_key = nil
    end

    set_loader_filter(to, player)
end

--- First paste from this assembler+recipe fills every loader filter slot; further pastes rotate one filter (slot 1) like before.
function Smarts.assembly_to_loader(from, to, player, special)
    local cycle = assembly_cycle(from)
    cycle = cycle_for_loader_filters(cycle)
    cycle = dedupe_item_cycles_preserve_order(cycle)
    if #cycle == 0 then return end

    local recipe, recipe_quality = from.get_recipe()
    local quality_name = recipe_quality and recipe_quality.name or "normal"
    local recipe_name = recipe and recipe.name or ""
    local asm_key = tostring(from.unit_number) .. ":" .. recipe_name .. ":" .. quality_name

    storage.entity_data[to.unit_number] = storage.entity_data[to.unit_number] or {}
    local entity = storage.entity_data[to.unit_number]
    entity.cycle = cycle

    if entity.assembly_paste_key == asm_key then
        set_loader_filter(to, player)
    else
        entity.cycle_index = 1
        entity.assembly_paste_key = asm_key
        apply_all_loader_filter_slots(to, cycle, player)
    end
end

-- function Smarts.constant_combinator_to_loader(from, to, player, special)
--     local cycle = constant_combinator_cycle(from)
--     if #cycle > 0 then update_loader(to, cycle, player) end
-- end

-- function Smarts.decider_arithmetic_combinator_to_loader(from, to, player, special)
--     local cycle = decider_arithmetic_combinator_cycle(from)
--     if #cycle > 0 then update_loader(to, cycle, player) end
-- end

function Smarts.container_to_loader(from, to, player, special)
    local cycle = container_cycle(from)
    if #cycle > 0 then update_loader(to, cycle, player) end
end

function Smarts.assembly_to_inserter(from, to, player, special)
    local ctrl = to.get_or_create_control_behavior()
    local c1 = ctrl.get_circuit_network(defines.wire_connector_id.circuit_red)
    local c2 = ctrl.get_circuit_network(defines.wire_connector_id.circuit_green)

    local fromRecipe, quality = from.get_recipe()

    if fromRecipe == nil then
        -- clear logistic
        if ctrl.connect_to_logistic_network then
            ctrl.logistic_condition = nil
            ctrl.connect_to_logistic_network = false
        end
        -- clear circuit
        if ctrl.circuit_enable_disable then
            ctrl.circuit_condition = nil
            ctrl.circuit_enable_disable = false
        end
        -- Clear filters
        to.use_filters = false
        for idx = 1, to.filter_slot_count do
            to.set_filter(idx, nil)
        end
        local ed = storage.entity_data[to.unit_number]
        if ed then
            ed.assembly_paste_key = nil
        end
    else
        local product = fromRecipe.products[1].name
        local item = prototypes.item[product]

        if item ~= nil then
            local comparator = settings.get_player_settings(player)["additional-paste-settings-options-comparator-value"].value
            local multiplier = settings.get_player_settings(player)["additional-paste-settings-options-inserter-multiplier-value"].value ---@cast multiplier double
            local mtype = settings.get_player_settings(player)["additional-paste-settings-options-inserter-multiplier-type"].value
            local additive = settings.get_player_settings(player)["additional-paste-settings-options-sumup"].value
            local amount = update_stack(mtype, multiplier, item, nil, fromRecipe, from.crafting_speed, additive, special)
            if c1 == nil and c2 == nil then
                if ctrl.connect_to_logistic_network and ctrl.logistic_condition.first_signal and ctrl.logistic_condition.first_signal.name == product then
                    if ctrl.logistic_condition.constant ~= nil then
                        amount = update_stack(mtype, multiplier, item, ctrl.logistic_condition.constant, fromRecipe, from.crafting_speed, additive, special)
                    end
                else
                    ctrl.connect_to_logistic_network = true
                end
                ctrl.logistic_condition = { comparator = comparator, first_signal = { type = "item", name = product, quality = quality.name }, constant = amount }
                storage.control_behaviour[to.unit_number] = Smarts.CopyControlBehavior(ctrl)
                local msg = "[img=item." .. product .. "] " .. comparator .. " " .. math.floor(amount)
                if player then player.create_local_flying_text({ text = msg, position = to.position, color = lib.colors.white }) end
            else
                if ctrl.circuit_enable_disable and ctrl.circuit_condition and ctrl.circuit_condition.first_signal and ctrl.circuit_condition.first_signal.name == product then
                    if ctrl.logistic_condition["constant"] ~= nil then
                        amount = update_stack(mtype, multiplier, item, ctrl.circuit_condition.constant, fromRecipe, from.crafting_speed, additive, special)
                    end
                else
                    ctrl.circuit_enable_disable = true
                end
                ctrl.circuit_condition = { comparator = comparator, first_signal = { type = "item", name = product, quality = quality.name }, constant = amount }
                storage.control_behaviour[to.unit_number] = Smarts.CopyControlBehavior(ctrl)
                local msg = "[img=item." .. product .. "] " .. comparator .. " " .. math.floor(amount)
                if player then player.create_local_flying_text({ text = msg, position = to.position, color = lib.colors.white }) end
            end
        end

        -- Item filters: first paste fills all slots from recipe; same assembler+recipe then rotates slot 1 (like loader).
        local filter_cycle = assembly_cycle(from)
        filter_cycle = cycle_for_loader_filters(filter_cycle)
        filter_cycle = dedupe_item_cycles_preserve_order(filter_cycle)
        if #filter_cycle > 0 then
            local quality_name = quality and quality.name or "normal"
            local asm_key = tostring(from.unit_number) .. ":" .. fromRecipe.name .. ":" .. quality_name
            storage.entity_data[to.unit_number] = storage.entity_data[to.unit_number] or {}
            local entity = storage.entity_data[to.unit_number]
            entity.cycle = filter_cycle
            if entity.assembly_paste_key == asm_key then
                set_inserter_cycle_filter(to, player)
            else
                entity.cycle_index = 1
                entity.assembly_paste_key = asm_key
                apply_all_inserter_filter_slots(to, filter_cycle, player)
            end
        end
    end
end

function Smarts.on_hotkey_pressed(event)
    local player = game.players[event.player_index]
    local special = nil

    if event.input_name and event.input_name == "additional-paste-settings-hotkey-alt" then
        special = 0.5
    end

    if player ~= nil and player.connected then
        local from = player.entity_copy_source
        local to = player.selected

        if from ~= nil and to ~= nil and from.valid and to.valid then
            local key = entity_action_type(from) .. "|" .. entity_action_type(to)
            local act = Smarts.actions[key]

            if act ~= nil then
                act(from, to, player, special)
            end
        end
    end
end

---@param event EventData.on_pre_entity_settings_pasted
function Smarts.on_vanilla_pre_paste(event)
    local src = event.source
    local dst = event.destination

    local src_ctrl = src.get_or_create_control_behavior()
    local dst_ctrl = dst.get_or_create_control_behavior()

    -- local evt = storage.event_backup[src.position.x .. "-" .. src.position.y .. "-" .. dst.position.x .. "-" .. dst.position.y]
    local evt = Smarts.GetEventBackup(src, dst)
    if not evt then
        evt = { gamer = event.player_index, stacks = {} }
    end

    evt.src_ctrl = Smarts.CopyControlBehavior(src_ctrl)
    evt.dst_ctrl = Smarts.CopyControlBehavior(dst_ctrl)

    local dst_proto = entity_effective_prototype(dst)
    if entity_action_type(src) == "assembling-machine" and entity_action_type(dst) == "logistic-container" and (dst_proto.logistic_mode == "requester" or dst_proto.logistic_mode == "buffer") then
        if evt ~= nil then
            local rows = dst.get_requester_point().filters
            if rows then
                for _, row in pairs(rows) do
                    local name = row.name .. "^" .. row.quality
                    local count = row.count
                    local quality = row.quality or "normal"
                    if name then
                        evt.stacks[name] = { name = row.name, count = count, quality = quality }
                    end
                end
            end
        end
    end

    -- storage.event_backup[src.position.x .. "-" .. src.position.y .. "-" .. dst.position.x .. "-" .. dst.position.y] = evt
    Smarts.SetEventBackup(src, dst, evt)
end

---@param event EventData.on_entity_settings_pasted
function Smarts.on_vanilla_paste(event)
    local src = event.source
    local dst = event.destination

    if entity_action_type(src) == "inserter" and entity_action_type(dst) == "inserter" then return end

    local src_ctrl = src.get_or_create_control_behavior()
    local dst_ctrl = dst.get_or_create_control_behavior()

    -- local evt = storage.event_backup[src.position.x .. "-" .. src.position.y .. "-" .. dst.position.x .. "-" .. dst.position.y]
    local evt = Smarts.GetEventBackup(src, dst)
    local player = game.get_player(event.player_index) ---@cast player LuaPlayer

    -- reapply old control behavior
    if storage.control_behaviour[src.unit_number] then
        for key, value in pairs(storage.control_behaviour[src.unit_number]) do
            pcall(function()
                src_ctrl[key] = value
            end)
        end
    end

    if storage.control_behaviour[dst.unit_number] then
        for key, value in pairs(storage.control_behaviour[dst.unit_number]) do
            pcall(function()
                dst_ctrl[key] = value
            end)
        end
    end

    local dst_proto_paste = entity_effective_prototype(dst)
    if evt ~= nil and entity_action_type(src) == "assembling-machine" and entity_action_type(dst) == "logistic-container" and (dst_proto_paste.logistic_mode == "requester" or dst_proto_paste.logistic_mode == "buffer") then
        local result = {}
        local multiplier = settings.get_player_settings(event.player_index)["additional-paste-settings-options-requester-multiplier-value"].value ---@cast multiplier double
        local mtype = settings.get_player_settings(event.player_index)["additional-paste-settings-options-requester-multiplier-type"].value
        local recipe, quality = src.get_recipe()
        local speed = src.crafting_speed
        local additive = settings.get_player_settings(event.player_index)["additional-paste-settings-options-sumup"].value
        local invertPaste = settings.get_player_settings(event.player_index)["additional-paste-settings-options-invert-buffer"].value and dst_proto_paste.logistic_mode == "buffer"
        local requestFromBuffers = settings.get_player_settings(event.player_index)["additional-paste-settings-options-request-from-buffer"].value ---@cast requestFromBuffers boolean
        if invertPaste and dst_proto_paste.logistic_mode == "buffer" then
            mtype = "additional-paste-settings-per-stack-size"
            multiplier = settings.get_player_settings(event.player_index)["additional-paste-settings-options-invert-buffer-multiplier-value"].value ---@cast multiplier double
        end
        if dst_proto_paste.logistic_mode == "requester" then
            dst.request_from_buffers = requestFromBuffers
        end

        local post_stacks = {}
        local requester_point = dst.get_requester_point()
        if requester_point and requester_point.filters and #requester_point.filters > 0 then
            for _, row in pairs(requester_point.filters) do
                if row and row.name then
                    local name = row.name .. "^" .. row.quality
                    post_stacks[name] = { name = row.name, count = row.count, quality = row.quality }
                    if (not evt.stacks[name]) then
                        evt.stacks[name] = { name = row.name, count = 0, quality = row.quality }
                    end
                end
            end
        end

        for key, row in pairs(evt.stacks) do
            local post, prior
            prior = { name = row.name, count = row.count, quality = row.quality }
            if post_stacks[key] then
                post = { name = row.name, count = post_stacks[key].count, quality = row.quality }
            else
                post = { name = row.name, count = 0, quality = row.quality }
            end

            if prior ~= {} then
                if result[key] ~= nil then
                    result[key].count = update_stack(mtype, multiplier, prior, result[key].count, recipe, speed, additive)
                else
                    result[key] = { name = row.name, count = prior.count, quality = row.quality }
                end
            end

            if post ~= nil then
                if invertPaste then
                    if result[key] ~= nil then
                        result[key].count = update_stack(mtype, -1 * multiplier, post, result[key].count, recipe, speed, additive)
                    else
                        result[key] = { name = row.name, count = 0, quality = row.quality }
                    end
                else
                    if result[key] ~= nil then
                        result[key].count = update_stack(mtype, multiplier, post, result[key].count, recipe, speed, additive)
                    else
                        result[key] = {
                            name = row.name,
                            count = update_stack(mtype, multiplier, post, nil, recipe, speed, additive)
                        }
                    end
                end
            end
        end

        if invertPaste and recipe then
            for k, product in pairs(recipe.products) do
                if product.type ~= "fluid" then
                    if result[product.name] ~= nil then
                        result[product.name].count = update_stack(mtype, multiplier, result[product.name], result[product.name].count, recipe, speed, additive)
                    else
                        result[product.name] = {
                            name = product.name,
                            count = update_stack(mtype, multiplier, { name = product.name }, prototypes.item[product.name].stack_size, recipe, speed, additive),
                            quality = quality.name or "normal"
                        }
                    end
                end
            end
        end

        local section = Smarts.FindAvailableLogisticsSection(dst)
        if section then
            for idx, _ in pairs(section.filters) do
                section.clear_slot(idx)
            end

            local i = 1
            local msg = ""
            for key, row in pairs(result) do
                if row and row.count and row.count > 0 then
                    local quality = row.quality or "normal"
                    section.set_slot(i, { value = { name = row.name, quality = quality }, min = row.count })
                    -- msg = msg .. "[img=item." .. row.name .. ",quality=" .. quality .. "] = " .. row.count .. " "
                    msg = msg .. "[item=" .. row.name .. ",quality=" .. quality .. "] = " .. row.count .. " "
                    i = i + 1
                end
            end
            if player then player.create_local_flying_text({ text = msg, position = dst.position, color = lib.colors.white }) end
        end
    end

    -- Smart things with filters
    local smart_filters = settings.get_player_settings(player)["additional-paste-settings-options-smart_filters"].value
    if smart_filters and entity_action_type(src) == "assembling-machine" and entity_action_type(dst) == "inserter" then
        local inserter = dst
        local pickup_target = inserter.pickup_target --@cast LuaEntity
        if pickup_target and entity_action_type(pickup_target) == "assembling-machine" then
            local recipe, quality = pickup_target.get_recipe()
            if recipe and recipe.products[1] and recipe.products[1].type ~= 'fluid' then
                for i = 1, inserter.filter_slot_count do inserter.set_filter(i, nil) end
                inserter.set_filter(1, { name = recipe.products[1].name, quality = quality.name })
            end
        end
    end

    -- Disable filters
    local disable_filters = settings.get_player_settings(player)["additional-paste-settings-options-disable_filters"].value
    if disable_filters and entity_action_type(dst) == "inserter" then
        if dst.use_filters then
            dst.use_filters = false
            for idx = 1, dst.filter_slot_count do
                dst.set_filter(idx, nil)
            end
        end
    end

    -- storage.event_backup[src.position.x .. "-" .. src.position.y .. "-" .. dst.position.x .. "-" .. dst.position.y] = nil
    Smarts.SetEventBackup(src, dst, nil)
end

function Smarts.get_translations()
    storage.locale_dictionaries = remote.call("Babelfish", "get_translations")
end

---@type table<string, fun(from: LuaEntity, to: LuaEntity, player?: LuaPlayer|nil, special?: number|nil)>
Smarts.actions = {
    --  SE cargo landing pad actions
    -- ["container|container"] = Smarts.container_to_container,
    -- ["logistic-container|container"] = Smarts.container_to_container,
    -- ["arithmetic-combinator|container"] = Smarts.decider_arithmetic_combinator_to_container,
    -- ["decider-combinator|container"] = Smarts.decider_arithmetic_combinator_to_container,
    -- ["constant-combinator|container"] = Smarts.constant_combinator_to_container,
    -- ["assembling-machine|container"] = Smarts.assembly_to_container,

    -- SpaceAge things
    -- ["assembling-machine|display-panel"] = Smarts.assembling_to_display_panel,

    --  SE + DisplayPlate actions
    -- ["simple-entity-with-owner|container"] = Smarts.simple_entity_with_owner_to_container,

    --  DisplayPlate actions
    -- ["container|simple-entity-with-owner"] = Smarts.container_to_simple_entity_with_owner,
    -- ["logistic-container|simple-entity-with-owner"] = Smarts.container_to_simple_entity_with_owner,
    -- ["arithmetic-combinator|simple-entity-with-owner"] = Smarts.decider_arithmetic_combinator_to_simple_entity_with_owner,
    -- ["decider-combinator|simple-entity-with-owner"] = Smarts.decider_arithmetic_combinator_to_simple_entity_with_owner,
    -- ["constant-combinator|simple-entity-with-owner"] = Smarts.constant_combinator_to_simple_entity_with_owner,
    -- ["assembling-machine|simple-entity-with-owner"] = Smarts.assembly_to_simple_entity_with_owner,

    --  Train station actions
    -- ["constant-combinator|train-stop"] = Smarts.constant_combinator_to_train_stop,
    -- ["decider-combinator|train-stop"] = Smarts.decider_arithmetic_combinator_to_train_stop,
    -- ["arithmetic-combinator|train-stop"] = Smarts.decider_arithmetic_combinator_to_train_stop,
    ["container|train-stop"] = Smarts.container_to_train_stop,
    ["assembling-machine|train-stop"] = Smarts.assembly_to_train_stop,

    --  Loader support
    ["container|loader"] = Smarts.container_to_loader,
    ["logistic-container|loader"] = Smarts.container_to_loader,
    -- ["arithmetic-combinator|loader"] = Smarts.decider_arithmetic_combinator_to_loader,
    -- ["decider-combinator|loader"] = Smarts.decider_arithmetic_combinator_to_loader,
    -- ["constant-combinator|loader"] = Smarts.constant_combinator_to_loader,
    ["assembling-machine|loader"] = Smarts.assembly_to_loader,

    --  Loader support  1x1
    ["container|loader-1x1"] = Smarts.container_to_loader,
    ["logistic-container|loader-1x1"] = Smarts.container_to_loader,
    -- ["arithmetic-combinator|loader-1x1"] = Smarts.decider_arithmetic_combinator_to_loader,
    -- ["decider-combinator|loader-1x1"] = Smarts.decider_arithmetic_combinator_to_loader,
    -- ["constant-combinator|loader-1x1"] = Smarts.constant_combinator_to_loader,
    ["assembling-machine|loader-1x1"] = Smarts.assembly_to_loader,

    ["loader|inserter"] = Smarts.loader_to_inserter,
    ["inserter|loader"] = Smarts.inserter_to_loader,
    ["loader-1x1|inserter"] = Smarts.loader_to_inserter,
    ["inserter|loader-1x1"] = Smarts.inserter_to_loader,

    --  To Decider combinator
    -- ["container|decider-combinator"] = Smarts.container_to_decider_arithmetic_combinator,
    -- ["logistic-container|decider-combinator"] = Smarts.container_to_decider_arithmetic_combinator,
    -- ["assembling-machine|decider-combinator"] = Smarts.assembling_to_decider_arithmetic_combinator,
    -- ["constant-combinator|decider-combinator"] = Smarts.constant_combinator_to_decider_arithmetic_combinator,

    --  To Arithmetic combinator
    -- ["container|arithmetic-combinator"] = Smarts.container_to_decider_arithmetic_combinator,
    -- ["logistic-container|arithmetic-combinator"] = Smarts.container_to_decider_arithmetic_combinator,
    -- ["assembling-machine|arithmetic-combinator"] = Smarts.assembling_to_decider_arithmetic_combinator,
    -- ["constant-combinator|arithmetic-combinator"] = Smarts.constant_combinator_to_decider_arithmetic_combinator,

    --  Old actions
    ["assembling-machine|transport-belt"] = Smarts.assembly_to_transport_belt,
    ["assembling-machine|inserter"] = Smarts.assembly_to_inserter,
    ["assembling-machine|logistic-container"] = Smarts.assembly_to_logistic_chest,
    -- ["assembling-machine|constant-combinator"] = Smarts.assembly_to_constant_combinator,
    -- ["logistic-container|logistic-container"] = Smarts.clear_requester_chest,
    ["inserter|inserter"] = Smarts.clear_inserter_settings
}

return Smarts
