local support = require("support.domain_support")
local with_patches = support.with_patches
local config_sanity = require("src.config.gameplay.config_sanity")
local market_cfg = require("src.config.content.market")
local chance_cfg = require("src.config.content.chance_cards")
local tiles_cfg = require("src.config.content.tiles")
local runtime_refs = require("src.config.content.runtime_refs")
local board_feedback_catalog = require("src.ui.render.board_feedback_catalog")

local function _test_config_sanity_validate_passes_current_generated_data()
  config_sanity.reset_for_tests()
  assert(config_sanity.validate() == true, "current generated config should pass sanity checks")
end

local function _assert_validate_fails(message_fragment)
  config_sanity.reset_for_tests()
  local ok, err = pcall(config_sanity.validate)
  assert(ok == false, "config sanity validate should fail")
  assert(
    tostring(err):find(message_fragment, 1, true) ~= nil,
    "config sanity error should mention: " .. tostring(message_fragment) .. ", got: " .. tostring(err)
  )
end

local function _replace_table_rows(target, rows)
  for i = #target, 1, -1 do
    target[i] = nil
  end
  for i, row in ipairs(rows or {}) do
    target[i] = row
  end
end

local function _with_release_tables(chance_rows, market_rows, fn)
  local chance_backup = {}
  local market_backup = {}
  for i, row in ipairs(chance_cfg) do
    chance_backup[i] = row
  end
  for i, row in ipairs(market_cfg) do
    market_backup[i] = row
  end

  local function restore()
    _replace_table_rows(chance_cfg, chance_backup)
    _replace_table_rows(market_cfg, market_backup)
  end

  _replace_table_rows(chance_cfg, chance_rows)
  _replace_table_rows(market_cfg, market_rows)
  local ok, err = pcall(fn)
  restore()
  if not ok then
    error(err)
  end
end

local function _with_runtime_ref_tables(board_feedback, audio_refs, effect_refs, fn)
  with_patches({
    {
      target = runtime_refs,
      key = "board_feedback",
      value = board_feedback,
    },
    {
      target = runtime_refs,
      key = "audio",
      value = audio_refs,
    },
    {
      target = runtime_refs,
      key = "effects",
      value = effect_refs,
    },
  }, fn)
end

local function _test_chance_forced_move_destinations_are_valid_tiles()
  local tile_exists_by_id = {}
  for _, tile in ipairs(tiles_cfg) do
    tile_exists_by_id[tile.id] = true
  end
  local by_id = {}
  for _, card in ipairs(chance_cfg) do
    by_id[card.id] = card
    if card.effect == "forced_move" then
      assert(card.destination_tile_id ~= nil, "forced_move card missing destination_tile_id: " .. tostring(card.id))
      assert(card.destination == nil, "forced_move card should not use legacy destination field: " .. tostring(card.id))
      assert(
        tile_exists_by_id[card.destination_tile_id] == true,
        "forced_move card destination_tile_id not found in tiles: "
          .. tostring(card.destination_tile_id)
          .. " (card_id="
          .. tostring(card.id)
          .. ")"
      )
    end
  end

  assert(by_id[3031] and by_id[3031].destination_tile_id == 36, "card 3031 should point to hospital tile 36")
  assert(by_id[3032] and by_id[3032].destination_tile_id == 37, "card 3032 should point to mountain tile 37")
  assert(by_id[3033] and by_id[3033].destination_tile_id == 38, "card 3033 should point to tax tile 38")
  assert(by_id[3034] and by_id[3034].destination_tile_id == 39, "card 3034 should point to market tile 39")
end

local function _test_board_feedback_audio_refs_exist_in_runtime_refs()
  local cues = runtime_refs.board_feedback or {}
  local audio_refs = runtime_refs.audio or {}
  local effect_refs = runtime_refs.effects or {}

  for cue_name, cue in pairs(cues) do
    local effect_id_ref = cue and cue.effect_id_ref or nil
    if effect_id_ref ~= nil then
      assert(effect_refs[effect_id_ref] ~= nil, "missing effect ref for cue: " .. tostring(cue_name))
    end
    local sound_id_ref = cue and cue.sound_id_ref or nil
    if sound_id_ref ~= nil then
      assert(audio_refs[sound_id_ref] ~= nil, "missing audio ref for cue: " .. tostring(cue_name))
    end
    local followup_sounds = cue and cue.followup_sounds or nil
    if type(followup_sounds) == "table" then
      for index, entry in ipairs(followup_sounds) do
        local followup_ref = entry and entry.sound_id_ref or nil
        if followup_ref ~= nil then
          assert(
            audio_refs[followup_ref] ~= nil,
            "missing followup audio ref for cue: " .. tostring(cue_name) .. " index=" .. tostring(index)
          )
        end
      end
    end
  end
end

local function _test_cash_burst_board_feedback_binds_above_player()
  local cue = assert(board_feedback_catalog.get("cash_burst"), "cash_burst cue should exist")
  assert(cue.bind_to_player == true, "cash_burst should bind to player")
  assert(cue.socket_name == "Bip001", "cash_burst should bind to Bip001 socket")
  assert(type(cue.bind_offset) == "table", "cash_burst bind_offset should resolve to vector")
  assert(cue.bind_offset.y == 1.6, "cash_burst bind_offset should move effect above player head")
end

local function _test_config_sanity_rejects_vehicle_chance_cards()
  _with_release_tables({
    { id = 99001, effect = "set_vehicle", vehicle_id = 4001 },
  }, {}, function()
    _assert_validate_fails("config must not include chance set_vehicle cards")
  end)
end

local function _test_config_sanity_rejects_vehicle_market_entries()
  _with_release_tables({}, {
    { kind = "vehicle", product_id = 4001 },
  }, function()
    _assert_validate_fails("config must not include vehicle market entries")
  end)
end

local function _test_config_sanity_validate_rejects_missing_board_feedback_effect_ref()
  _with_runtime_ref_tables({
    cue = {
      effect_id_ref = "missing_effect",
    },
  }, {}, {}, function()
    _assert_validate_fails("board feedback cue references unknown effect_id_ref")
  end)
end

local function _test_config_sanity_validate_rejects_missing_board_feedback_followup_sound_ref()
  _with_runtime_ref_tables({
    cue = {
      followup_sounds = {
        { sound_id_ref = "missing_followup" },
      },
    },
  }, {}, {}, function()
    _assert_validate_fails("board feedback followup references unknown sound_id_ref")
  end)
end

local function _test_config_sanity_validate_rejects_missing_board_feedback_sound_ref()
  _with_runtime_ref_tables({
    cue = {
      sound_id_ref = "missing_sound",
    },
  }, {}, {}, function()
    _assert_validate_fails("board feedback cue references unknown sound_id_ref")
  end)
end

local function _test_config_sanity_validate_rejects_unknown_vehicle_refs()
  _with_release_tables({
    { id = 99002, effect = "set_vehicle", vehicle_id = "missing_vehicle" },
  }, {}, function()
    _assert_validate_fails("config must not include chance set_vehicle cards")
  end)

  _with_release_tables({}, {
    { kind = "vehicle", product_id = "missing_product" },
  }, function()
    _assert_validate_fails("config must not include vehicle market entries")
  end)
end

local function _test_config_sanity_validate_is_cached_until_reset()
  config_sanity.reset_for_tests()
  assert(config_sanity.validate() == true, "first validate should pass on generated data")

  _with_runtime_ref_tables({
    cue = {
      effect_id_ref = "missing_effect",
    },
  }, {}, {}, function()
    assert(config_sanity.validate() == true, "validated cache should skip re-validating until reset")
    _assert_validate_fails("board feedback cue references unknown effect_id_ref")
  end)
end

return {
  name = "config_sanity",
  tests = {
    { name = "config_sanity_validate_passes_current_generated_data", run = _test_config_sanity_validate_passes_current_generated_data },
    {
      name = "chance_forced_move_destinations_are_valid_tiles",
      run = _test_chance_forced_move_destinations_are_valid_tiles,
    },
    {
      name = "board_feedback_audio_refs_exist_in_runtime_refs",
      run = _test_board_feedback_audio_refs_exist_in_runtime_refs,
    },
    {
      name = "cash_burst_board_feedback_binds_above_player",
      run = _test_cash_burst_board_feedback_binds_above_player,
    },
    {
      name = "config_sanity_rejects_vehicle_chance_cards",
      run = _test_config_sanity_rejects_vehicle_chance_cards,
    },
    {
      name = "config_sanity_rejects_vehicle_market_entries",
      run = _test_config_sanity_rejects_vehicle_market_entries,
    },
    {
      name = "config_sanity_validate_rejects_missing_board_feedback_effect_ref",
      run = _test_config_sanity_validate_rejects_missing_board_feedback_effect_ref,
    },
    {
      name = "config_sanity_validate_rejects_missing_board_feedback_followup_sound_ref",
      run = _test_config_sanity_validate_rejects_missing_board_feedback_followup_sound_ref,
    },
    {
      name = "config_sanity_validate_rejects_missing_board_feedback_sound_ref",
      run = _test_config_sanity_validate_rejects_missing_board_feedback_sound_ref,
    },
    {
      name = "config_sanity_validate_rejects_unknown_vehicle_refs",
      run = _test_config_sanity_validate_rejects_unknown_vehicle_refs,
    },
    {
      name = "config_sanity_validate_is_cached_until_reset",
      run = _test_config_sanity_validate_is_cached_until_reset,
    },
  },
}
