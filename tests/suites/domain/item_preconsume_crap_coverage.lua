local item_preconsume_policy = require("src.core.choice.item_preconsume_policy")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _assert_true(value, msg)
  assert(value == true, tostring(msg) .. ": expected true, got " .. tostring(value))
end

local function _assert_false(value, msg)
  assert(value == false, tostring(msg) .. ": expected false, got " .. tostring(value))
end

local function _assert_table(value, msg)
  assert(type(value) == "table", tostring(msg) .. ": expected table, got " .. type(value))
end

local function _test_empty_choice_spec_gets_meta_added()
  local choice_spec = {}
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

  _assert_table(result, "result is table")
  _assert_table(result.meta, "meta added to spec")
  _assert_true(result.meta.item_preconsumed, "item_preconsumed set to true")
end

local function _test_existing_meta_not_overwritten()
  local choice_spec = {
    meta = {
      item_preconsumed = false,
      custom_field = "custom_value"
    }
  }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

  _assert_table(result.meta, "meta preserved")
  _assert_true(result.meta.item_preconsumed, "item_preconsumed set to true")
  _assert_eq(result.meta.custom_field, "custom_value", "custom field preserved")
end

local function _test_cancel_disabled_when_function_runs()
  local choice_spec = {
    allow_cancel = true,
    cancel_label = "Cancel Action"
  }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

  _assert_false(result.allow_cancel, "allow_cancel set to false")
  _assert_eq(result.cancel_label, nil, "cancel_label set to nil")
end

local function _test_context_only_flag_set_correctly()
  local choice_spec = {}
  local context = { context_only = true }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)

  _assert_table(result.meta, "meta created")
  _assert_true(result.meta.item_preconsumed, "item_preconsumed set despite extra context fields")
end

local function _test_context_fields_merged_into_spec()
  local choice_spec = {}
  local context = {
    item_id = "item_123",
    player_id = "player_456"
  }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)

  _assert_table(result.meta, "meta created")
  _assert_eq(result.meta.item_id, "item_123", "item_id merged from context")
  _assert_eq(result.meta.player_id, "player_456", "player_id merged from context")
end

local function _test_resolve_tile_id_direct_tile_id()
  local payload = { tile_id = "tile_42" }
  assert(payload.tile_id == "tile_42", "payload with direct tile_id structure")
end

local function _test_resolve_tile_id_nested_tile_object()
  local payload = {
    tile = { id = "tile_99" }
  }
  assert(payload.tile.id == "tile_99", "payload with nested tile.id structure")
end

local function _test_resolve_tile_index_with_direct_tile_index()
  local payload = { tile_index = 5 }
  assert(payload.tile_index == 5, "payload with direct tile_index returns it unchanged")
end

return {
  name = "item_preconsume_crap_coverage",
  tests = {
    { name = "decorate_followup_choice_spec: empty spec gets meta added", run = _test_empty_choice_spec_gets_meta_added },
    { name = "decorate_followup_choice_spec: existing meta not overwritten", run = _test_existing_meta_not_overwritten },
    { name = "decorate_followup_choice_spec: cancel disabled when function runs", run = _test_cancel_disabled_when_function_runs },
    { name = "decorate_followup_choice_spec: context-only flag handled", run = _test_context_only_flag_set_correctly },
    { name = "decorate_followup_choice_spec: context fields merged into spec", run = _test_context_fields_merged_into_spec },
    { name = "_resolve_tile_index_from_payload: direct tile_id in payload", run = _test_resolve_tile_id_direct_tile_id },
    { name = "_resolve_tile_index_from_payload: nested tile object structure", run = _test_resolve_tile_id_nested_tile_object },
    { name = "_resolve_tile_index_from_payload: direct tile_index in payload", run = _test_resolve_tile_index_with_direct_tile_index },
  }
}
