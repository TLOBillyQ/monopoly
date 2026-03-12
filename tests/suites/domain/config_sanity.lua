local support = require("support.domain_support")
local with_patches = support.with_patches
local config_sanity = require("src.core.config.config_sanity")
local market_cfg = require("Config.generated.market")
local chance_cfg = require("Config.generated.chance_cards")
local tiles_cfg = require("Config.generated.tiles")
local runtime_refs = require("Config.runtime_refs")
local vehicle_catalog = require("src.core.config.vehicle_catalog")

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

  assert(by_id[3031] and by_id[3031].destination_tile_id, "card 3031 should exist")
  assert(by_id[3033] and by_id[3033].destination_tile_id, "card 3033 should exist")
  assert(tile_exists_by_id[by_id[3031].destination_tile_id] == true, "card 3031 destination should exist in tiles")
  assert(tile_exists_by_id[by_id[3033].destination_tile_id] == true, "card 3033 destination should exist in tiles")
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

local function _test_config_sanity_release_build_rejects_vehicle_chance_cards()
  local vehicle_id = vehicle_catalog.list()[1].id
  with_patches({
    {
      target = _G,
      key = "RELEASE_BUILD",
      value = true,
    },
  }, function()
    _with_release_tables({
      { id = 99001, effect = "set_vehicle", vehicle_id = vehicle_id },
    }, {}, function()
      _assert_validate_fails("release config must not include chance set_vehicle cards")
    end)
  end)
end

local function _test_config_sanity_release_build_rejects_vehicle_market_entries()
  local vehicle_id = vehicle_catalog.list()[1].id
  with_patches({
    {
      target = _G,
      key = "RELEASE_BUILD",
      value = "TRUE",
    },
  }, function()
    _with_release_tables({}, {
      { kind = "vehicle", product_id = vehicle_id },
    }, function()
      _assert_validate_fails("release config must not include vehicle market entries")
    end)
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
  local original_has = vehicle_catalog.has
  with_patches({
    {
      target = vehicle_catalog,
      key = "has",
      value = function(id)
        if id == "missing_vehicle" or id == "missing_product" then
          return false
        end
        return original_has(id)
      end,
    },
  }, function()
    _with_release_tables({
      { id = 99002, effect = "set_vehicle", vehicle_id = "missing_vehicle" },
    }, {}, function()
      _assert_validate_fails("chance card references unknown vehicle_id")
    end)

    _with_release_tables({}, {
      { kind = "vehicle", product_id = "missing_product" },
    }, function()
      _assert_validate_fails("market entry references unknown vehicle product_id")
    end)
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
      name = "config_sanity_release_build_rejects_vehicle_chance_cards",
      run = _test_config_sanity_release_build_rejects_vehicle_chance_cards,
    },
    {
      name = "config_sanity_release_build_rejects_vehicle_market_entries",
      run = _test_config_sanity_release_build_rejects_vehicle_market_entries,
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
