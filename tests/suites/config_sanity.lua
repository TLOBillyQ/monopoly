local support = require("TestSupport")
local with_patches = support.with_patches
local config_sanity = require("src.core.config.ConfigSanity")
local market_cfg = require("Config.Generated.Market")
local chance_cfg = require("Config.Generated.ChanceCards")
local tiles_cfg = require("Config.Generated.Tiles")
local runtime_refs = require("Config.RuntimeRefs")

local function _test_config_sanity_validate_passes_current_generated_data()
  config_sanity.reset_for_tests()
  assert(config_sanity.validate() == true, "current generated config should pass sanity checks")
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

  for cue_name, cue in pairs(cues) do
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
  },
}
