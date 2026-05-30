local support = require("spec.support.shared_support")
local with_patches = support.with_patches
local config_sanity = require("src.config.gameplay.config_sanity")
local chance_cfg = require("src.config.content.chance_cards")
local tiles_cfg = require("src.config.content.tiles")
local runtime_refs = require("src.config.content.runtime_refs")
local board_feedback_catalog = require("src.ui.render.board_feedback.catalog")


local function _assert_validate_fails(message_fragment)
  config_sanity.reset_for_tests()
  local ok, err = pcall(config_sanity.validate)
  assert(ok == false, "config sanity validate should fail")
  assert(
    tostring(err):find(message_fragment, 1, true) ~= nil,
    "config sanity error should mention: " .. tostring(message_fragment) .. ", got: " .. tostring(err)
  )
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

describe("config_sanity", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("config_sanity_validate_passes_current_generated_data", function()
    config_sanity.reset_for_tests()
    assert(config_sanity.validate() == true, "current generated config should pass sanity checks")
  end)

  it("chance_forced_move_destinations_are_valid_tiles", function()
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
  end)

  it("board_feedback_audio_refs_exist_in_runtime_refs", function()
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
  end)

  it("cash_burst_board_feedback_binds_above_player", function()
    local cue = assert(board_feedback_catalog.get("cash_burst"), "cash_burst cue should exist")
    assert(cue.bind_to_player == true, "cash_burst should bind to player")
    assert(cue.socket_name == "Bip001", "cash_burst should bind to Bip001 socket")
    assert(type(cue.bind_offset) == "table", "cash_burst bind_offset should resolve to vector")
    assert(cue.bind_offset.y == 1.6, "cash_burst bind_offset should move effect above player head")
  end)

  it("config_sanity_validate_rejects_missing_board_feedback_effect_ref", function()
    _with_runtime_ref_tables({
      cue = {
        effect_id_ref = "missing_effect",
      },
    }, {}, {}, function()
      _assert_validate_fails("board feedback cue references unknown effect_id_ref")
    end)
  end)

  it("config_sanity_validate_rejects_missing_board_feedback_followup_sound_ref", function()
    _with_runtime_ref_tables({
      cue = {
        followup_sounds = {
          { sound_id_ref = "missing_followup" },
        },
      },
    }, {}, {}, function()
      _assert_validate_fails("board feedback followup references unknown sound_id_ref")
    end)
  end)

  it("config_sanity_validate_rejects_missing_board_feedback_sound_ref", function()
    _with_runtime_ref_tables({
      cue = {
        sound_id_ref = "missing_sound",
      },
    }, {}, {}, function()
      _assert_validate_fails("board feedback cue references unknown sound_id_ref")
    end)
  end)

  it("config_sanity_validate_is_cached_until_reset", function()
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
  end)

  it("all_items_have_prompt_style", function()
    local items = require("src.config.content.items")
    for _, item in ipairs(items) do
      assert(
        item.prompt_style == "alert" or item.prompt_style == "passive",
        "item " .. tostring(item.id) .. " missing or invalid prompt_style: " .. tostring(item.prompt_style)
      )
    end
  end)

  it("effect_group_only_on_specified_items", function()
    local items = require("src.config.content.items")
    local items_with_effect_group = {}
    for _, item in ipairs(items) do
      if item.effect_group ~= nil then
        table.insert(items_with_effect_group, item.id)
      end
    end
    assert(
      #items_with_effect_group == 2,
      "expected exactly 2 items with effect_group, got " .. #items_with_effect_group .. " items: " .. table.concat(items_with_effect_group, ", ")
    )
    local effect_groups_by_id = {}
    for _, item in ipairs(items) do
      if item.effect_group then
        effect_groups_by_id[item.id] = item.effect_group
      end
    end
    assert(effect_groups_by_id[2002] == "dice_control", "item 2002 should have effect_group=dice_control")
    assert(effect_groups_by_id[2003] == "dice_multiply", "item 2003 should have effect_group=dice_multiply")
  end)
end)
