dofile("tests/test_bootstrap.lua")

package.path = package.path .. ";./?.lua"

local function assert_true(value, message)
    if not value then
        error(message or "assert_true failed")
    end
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(message or ("assert_equal failed: expected " .. tostring(expected) .. ", got " .. tostring(actual)))
    end
end

local function assert_table_len(list, expected, message)
    local count = 0
    for _ in pairs(list) do
        count = count + 1
    end
    if count ~= expected then
        error(message or ("assert_table_len failed: expected " .. expected .. ", got " .. count))
    end
end

local assert_count = 0
local function ok(value, message)
    assert_true(value, message)
    assert_count = assert_count + 1
end

local function eq(actual, expected, message)
    assert_equal(actual, expected, message)
    assert_count = assert_count + 1
end


math.tofixed = function(value)
    return value
end
math.tointeger = math.tointeger or function(value)
    return math.floor(value)
end

EVENT = {
    REPEAT_TIMEOUT = "REPEAT_TIMEOUT"
}

local function make_role(role_id, call_log)
    local role = {
        _id = role_id
    }

    function role.get_roleid()
        return role._id
    end

    local function record(name, ...)
        call_log[#call_log + 1] = { name = name, args = { ... }, role = role }
    end

    function role.set_node_visible(...) record("set_node_visible", ...) end
    function role.set_node_touch_enabled(...) record("set_node_touch_enabled", ...) end
    function role.set_label_text(...) record("set_label_text", ...) end
    function role.set_label_background_color(...) record("set_label_background_color", ...) end
    function role.set_label_background_opacity(...) record("set_label_background_opacity", ...) end
    function role.set_label_color(...) record("set_label_color", ...) end
    function role.set_label_font(...) record("set_label_font", ...) end
    function role.set_label_font_size(...) record("set_label_font_size", ...) end
    function role.set_label_outline_color(...) record("set_label_outline_color", ...) end
    function role.set_label_outline_enabled(...) record("set_label_outline_enabled", ...) end
    function role.set_label_outline_opacity(...) record("set_label_outline_opacity", ...) end
    function role.set_label_outline_width(...) record("set_label_outline_width", ...) end
    function role.set_label_shadow_color(...) record("set_label_shadow_color", ...) end
    function role.set_label_shadow_enabled(...) record("set_label_shadow_enabled", ...) end
    function role.set_label_shadow_x_offset(...) record("set_label_shadow_x_offset", ...) end
    function role.set_label_shadow_y_offset(...) record("set_label_shadow_y_offset", ...) end
    function role.set_button_text(...) record("set_button_text", ...) end
    function role.set_button_text_color(...) record("set_button_text_color", ...) end
    function role.set_button_font_size(...) record("set_button_font_size", ...) end
    function role.set_button_enabled(...) record("set_button_enabled", ...) end
    function role.set_image_color(...) record("set_image_color", ...) end
    function role.set_image_texture_by_key_with_auto_resize(...) record("set_image_texture_by_key_with_auto_resize", ...) end
    function role.set_progressbar_transition(...) record("set_progressbar_transition", ...) end
    function role.set_progressbar_max(...) record("set_progressbar_max", ...) end
    function role.set_progressbar_min(...) record("set_progressbar_min", ...) end
    function role.set_input_field_text(...) record("set_input_field_text", ...) end

    return role
end

local call_log = {}
local role_a = make_role(1, call_log)
local role_b = make_role(2, call_log)

local function find_last_call(name, id)
    for i = #call_log, 1, -1 do
        local call = call_log[i]
        if call.name == name and (id == nil or call.args[1] == id) then
            return call
        end
    end
    return nil
end

GameAPI = {}
LuaAPI = {}

local custom_events = {}
local trigger_events = {}
local next_trigger_id = 1

function LuaAPI.global_register_custom_event(event_name, callback)
    local trigger_id = next_trigger_id
    next_trigger_id = next_trigger_id + 1
    custom_events[event_name] = { id = trigger_id, callback = callback }
    return trigger_id
end

function LuaAPI.global_unregister_custom_event(trigger_id)
    for name, data in pairs(custom_events) do
        if data.id == trigger_id then
            custom_events[name] = nil
            return
        end
    end
end

function LuaAPI.global_send_custom_event(event_name, data)
    local record = custom_events[event_name]
    if record then
        record.callback(nil, nil, data)
    end
end

function LuaAPI.global_register_trigger_event(event_data, callback)
    local trigger_id = next_trigger_id
    next_trigger_id = next_trigger_id + 1
    trigger_events[trigger_id] = { data = event_data, callback = callback }
    return trigger_id
end

function LuaAPI.global_unregister_trigger_event(trigger_id)
    trigger_events[trigger_id] = nil
end

function GameAPI.get_all_valid_roles()
    return { role_a, role_b }
end

local config_list = {
    [1] = { "root", "ENode" },
    [2] = { "label", "ELabel" },
    [3] = { "button", "EButton" },
    [4] = { "container", "ENode" },
    [5] = { "image", "EImage" },
    [6] = { "progress", "EProgressbar" },
    [7] = { "input", "EInputField" },
    [8] = { "canvas", "ECanvas" }
}

local children_map = {
    [1] = { 2, 3, 4, 7 },
    [4] = { 5, 6 }
}

function GameAPI.get_eui_children(node_id)
    return children_map[node_id] or {}
end

function GameAPI.get_eui_child_by_name(node_id, name)
    local children = children_map[node_id] or {}
    for _, child_id in ipairs(children) do
        if config_list[child_id][1] == name then
            return child_id
        end
    end
    return nil
end

require "Library.ClassUtils"
require "Library.Utils"
local UIManager = require "Library.UIManager.Utils"

local builder = UIManager.Builder:new(config_list)

local root = UIManager.get_first_node_by_name("root")
local label = UIManager.get_first_node_by_name("label")
local button = UIManager.get_first_node_by_name("button")
local container = UIManager.get_first_node_by_name("container")
local image = UIManager.get_first_node_by_name("image")
local progress = UIManager.get_first_node_by_name("progress")
local input = UIManager.get_first_node_by_name("input")
local canvas = UIManager.get_first_node_by_name("canvas")

ok(root ~= nil, "root should exist")
ok(label ~= nil, "label should exist")
ok(button ~= nil, "button should exist")
ok(container ~= nil, "container should exist")
ok(image ~= nil, "image should exist")
ok(progress ~= nil, "progress should exist")
ok(input ~= nil, "input should exist")
ok(canvas ~= nil, "canvas should exist")

eq(root.children.length, 4, "root children length")
eq(container.children.length, 2, "container children length")
eq(label.parent, root, "label parent")
eq(image.parent, container, "image parent")

eq(root:get_first_node_by_name("label"), label, "root get_first_node_by_name")
eq(root:query_nodes_by_name("button")[1], button, "root query_nodes_by_name")
eq(root:get_first_node_by_name_dfs("image"), image, "root dfs find image")
eq(root:query_nodes_by_name_dfs("progress")[1], progress, "root dfs query progress")

label.visible = true
label.disabled = false
label.text = "hello"
label.text_color = 0xff0000
label.font_size = 12

local label_calls = {}
for _, call in ipairs(call_log) do
    if call.args[1] == 2 then
        label_calls[#label_calls + 1] = call
    end
end
ok(#label_calls >= 4, "label should update multiple properties")

UIManager.client_role = role_a
button.text = "btn"
local button_text_call = find_last_call("set_button_text", 3)
ok(button_text_call ~= nil, "button text updates for client role")
eq(button_text_call.role, role_a, "button text updates only for client role")
UIManager.client_role = nil

button.disabled = true
ok(find_last_call("set_node_touch_enabled", 3) ~= nil, "button disabled updates touch")
ok(find_last_call("set_button_enabled", 3) ~= nil, "button disabled updates button")

image.image_color = 0x00ff00
ok(find_last_call("set_image_color", 5) ~= nil, "image color updates")

progress.value = 50
progress.max_value = 100
progress.min_value = 0
ok(find_last_call("set_progressbar_transition", 6) ~= nil, "progress value updates")
ok(find_last_call("set_progressbar_max", 6) ~= nil, "progress max updates")
ok(find_last_call("set_progressbar_min", 6) ~= nil, "progress min updates")

input.text = "typing"
ok(find_last_call("set_input_field_text", 7) ~= nil, "input text updates")

label:set_attribute("tag", "ui")
eq(label:get_attribtue("tag"), "ui", "custom attributes")

local for_all_calls_before = #call_log
label:for_all_roles("text", "all")
local for_all_calls_after = #call_log
ok(for_all_calls_after - for_all_calls_before >= 2, "for_all_roles should update all roles")

local callback_called = false
local listener = button:listen(UIManager.EVENT.CLICK, function(data)
    callback_called = true
    eq(data.target, button, "listener data target")
    eq(data.role, role_b, "listener data role")
    eq(UIManager.client_role, role_b, "listener sets client_role")
end)

LuaAPI.global_send_custom_event(UIManager.EVENT.CLICK, { eui_node_id = button.id, role = role_b })
ok(callback_called, "listener callback called")

listener:destroy()
assert_table_len(UIManager.event_handlers, 0, "event handlers cleaned")
ok(custom_events[UIManager.EVENT.CLICK] == nil, "custom event unregistered")

local frameout_called = false
local frameout = SetFrameOut(3, function(data)
    frameout_called = true
    eq(data.frame, 3, "frameout frame increments")
end, 1, true)
ok(frameout_called, "frameout callback invoked")
ok(frameout == nil or frameout.destroy ~= nil, "frameout created")

print(("UIManager tests passed (%d)"):format(assert_count))
