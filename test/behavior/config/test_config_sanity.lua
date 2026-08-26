local lu = require("luaunit")
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local config_sanity = require("src.config.gameplay.config_sanity")
local chance_cfg = require("src.config.content.chance_cards")
local constants_cfg = require("src.config.content.constants")
local runtime_assets_cfg = require("src.config.runtime_assets")
local tiles_cfg = require("src.config.content.tiles")
local runtime_refs = require("src.config.content.runtime_refs")
local board_feedback_catalog = require("src.ui.render.board_feedback.catalog")
local _config_reset = require("test.support.config_reset")


local function _assert_validate_fails(message_fragment)
  config_sanity.reset_for_tests()
  local ok, err = pcall(config_sanity.validate)
  lu.assertEvalToTrue(ok == false, "config sanity validate should fail")
  local text = tostring(err)
  lu.assertEvalToTrue(
    text:find(message_fragment, 1, true) ~= nil,
    "config sanity error should mention: " .. tostring(message_fragment) .. ", got: " .. text
  )
  -- 配置错误一律 error(msg, 0):这些文案是要给宿主/策划看的,不该被 Lua 拼上
  -- 「<源文件>:<行号>: 」前缀。少写那个 0,报错就退化成源码坐标噪音。
  lu.assertEvalToTrue(
    text:match("^[^\n]-%.lua:%d+: ") == nil,
    "config sanity error must carry no source-position prefix, got: " .. text
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

TestConfigSanity = {}

function TestConfigSanity:setUp()
  _config_reset.reset_all()
  -- #328:目录校验器由测试配置(与装配侧同款 thunk)——补丁仍打在
  -- validate_catalog 字段上,thunk 在调用时读字段,补丁照常生效。
  config_sanity.configure_runtime_asset_validator(function()
    return runtime_assets_cfg.validate_catalog()
  end)
end

function TestConfigSanity:test_config_sanity_validate_passes_current_generated_data()
  config_sanity.reset_for_tests()
  lu.assertEvalToTrue(config_sanity.validate() == true, "current generated config should pass sanity checks")
end

-- tax_rules 靠这条约束省掉不可达的 fee 钳制:税率越界会让「本次税额」
-- 超过实际扣款,事件播报与账目对不上。约束破了必须在配置边界就炸。
-- 记忆化标志的初值。其余用例都先调 reset_for_tests(),等于每次都把它按回 false,
-- 于是「模块刚加载时就已经是已校验」这种退化没人拦得住——而 host_install 的
-- 启动校验正好走的就是那条首次调用路径,退化了会静默跳过全部配置校验。
function TestConfigSanity:test_config_sanity_skips_catalog_check_without_configured_validator()
  -- #328:未注入校验器时 validate() 只校验自身配置,不碰目录(依赖方向单一化
  -- 的代价面——目录校验是装配侧职责,缺接线时静默跳过而非反向依赖)。
  local module_name = "src.config.gameplay.config_sanity"
  local saved = package.loaded[module_name]
  package.loaded[module_name] = nil
  local fresh = require(module_name)

  local ok, err = pcall(function()
    local passed = fresh.validate()
    lu.assertEvalToTrue(passed == true,
      "a fresh config_sanity without a validator must still pass its own config checks")
  end)

  package.loaded[module_name] = saved
  if not ok then
    error(err, 0)
  end
end

function TestConfigSanity:test_config_sanity_validates_on_the_first_call_after_a_fresh_load()
  local module_name = "src.config.gameplay.config_sanity"
  local saved = package.loaded[module_name]
  package.loaded[module_name] = nil
  local fresh = require(module_name)

  local ok, err = pcall(function()
    with_patches({
      { target = constants_cfg, key = "tax_rate", value = 0 },
    }, function()
      -- 故意不调 reset_for_tests():要验的就是刚加载时尚未标记为已校验。
      local passed, validate_err = pcall(fresh.validate)
      lu.assertEvalToTrue(passed == false,
        "a freshly loaded config_sanity must actually validate on its first call")
      lu.assertEvalToTrue(tostring(validate_err):find("tax_rate must be a number in (0, 1]", 1, true) ~= nil,
        "the first call must surface the real config error, got: " .. tostring(validate_err))
    end)
  end)

  package.loaded[module_name] = saved
  if not ok then
    error(err, 0)
  end
end

function TestConfigSanity:test_config_sanity_validate_rejects_out_of_range_tax_rate()
  for _, bad_rate in ipairs({ 0, -0.5, 1.5 }) do
    with_patches({
      { target = constants_cfg, key = "tax_rate", value = bad_rate },
    }, function()
      _assert_validate_fails("tax_rate must be a number in (0, 1]")
    end)
  end

  with_patches({
    { target = constants_cfg, key = "tax_rate", value = "0.5" },
  }, function()
    _assert_validate_fails("tax_rate must be a number in (0, 1]")
  end)
end

function TestConfigSanity:test_config_sanity_validate_accepts_tax_rate_at_the_upper_bound()
  with_patches({
    { target = constants_cfg, key = "tax_rate", value = 1 },
  }, function()
    config_sanity.reset_for_tests()
    lu.assertEvalToTrue(config_sanity.validate() == true, "tax_rate = 1 is the inclusive upper bound")
  end)
end

-- 资产校验失败但拿不到具体条目时的兜底文案。既有用例都走「errors[1].message 存在」
-- 那一路,兜底串从没被驱动过,写错/写没了都不会有人发现。
function TestConfigSanity:test_config_sanity_validate_falls_back_to_a_generic_runtime_asset_message()
  for _, catalog_result in ipairs({ { ok = false }, { ok = false, errors = { {} } } }) do
    with_patches({
      {
        target = runtime_assets_cfg,
        key = "validate_catalog",
        value = function() return catalog_result end,
      },
    }, function()
      _assert_validate_fails("runtime asset catalog invalid")
    end)
  end
end

function TestConfigSanity:test_chance_forced_move_destinations_are_valid_tiles()
  local tile_exists_by_id = {}
  for _, tile in ipairs(tiles_cfg) do
    tile_exists_by_id[tile.id] = true
  end
  local by_id = {}
  for _, card in ipairs(chance_cfg) do
    by_id[card.id] = card
    if card.effect == "forced_move" then
      lu.assertEvalToTrue(card.destination_tile_id ~= nil, "forced_move card missing destination_tile_id: " .. tostring(card.id))
      lu.assertEvalToTrue(card.destination == nil, "forced_move card should not use legacy destination field: " .. tostring(card.id))
      lu.assertEvalToTrue(
        tile_exists_by_id[card.destination_tile_id] == true,
        "forced_move card destination_tile_id not found in tiles: "
          .. tostring(card.destination_tile_id)
          .. " (card_id="
          .. tostring(card.id)
          .. ")"
      )
    end
  end

  lu.assertEvalToTrue(by_id[3031] and by_id[3031].destination_tile_id == 36, "card 3031 should point to hospital tile 36")
  lu.assertEvalToTrue(by_id[3032] and by_id[3032].destination_tile_id == 37, "card 3032 should point to mountain tile 37")
  lu.assertEvalToTrue(by_id[3033] and by_id[3033].destination_tile_id == 38, "card 3033 should point to tax tile 38")
  lu.assertEvalToTrue(by_id[3034] and by_id[3034].destination_tile_id == 39, "card 3034 should point to market tile 39")
end

function TestConfigSanity:test_board_feedback_audio_refs_exist_in_runtime_refs()
  local cues = runtime_refs.board_feedback or {}
  local audio_refs = runtime_refs.audio or {}
  local effect_refs = runtime_refs.effects or {}

  for cue_name, cue in pairs(cues) do
    local effect_id_ref = cue and cue.effect_id_ref or nil
    if effect_id_ref ~= nil then
      lu.assertEvalToTrue(effect_refs[effect_id_ref] ~= nil, "missing effect ref for cue: " .. tostring(cue_name))
    end
    local sound_id_ref = cue and cue.sound_id_ref or nil
    if sound_id_ref ~= nil then
      lu.assertEvalToTrue(audio_refs[sound_id_ref] ~= nil, "missing audio ref for cue: " .. tostring(cue_name))
    end
    local followup_sounds = cue and cue.followup_sounds or nil
    if type(followup_sounds) == "table" then
      for index, entry in ipairs(followup_sounds) do
        local followup_ref = entry and entry.sound_id_ref or nil
        if followup_ref ~= nil then
          lu.assertEvalToTrue(
            audio_refs[followup_ref] ~= nil,
            "missing followup audio ref for cue: " .. tostring(cue_name) .. " index=" .. tostring(index)
          )
        end
      end
    end
  end
end

function TestConfigSanity:test_cash_burst_board_feedback_binds_above_player()
  local cue = assert(board_feedback_catalog.get("cash_burst"), "cash_burst cue should exist")
  lu.assertEvalToTrue(cue.bind_to_player == true, "cash_burst should bind to player")
  lu.assertEvalToTrue(cue.socket_name == "Bip001", "cash_burst should bind to Bip001 socket")
  lu.assertEvalToTrue(type(cue.bind_offset) == "table", "cash_burst bind_offset should resolve to vector")
  lu.assertEvalToTrue(cue.bind_offset.y == 1.6, "cash_burst bind_offset should move effect above player head")
end

function TestConfigSanity:test_config_sanity_validate_rejects_missing_board_feedback_effect_ref()
  _with_runtime_ref_tables({
    cue = {
      effect_id_ref = "missing_effect",
    },
  }, {}, {}, function()
    _assert_validate_fails("board feedback cue references unknown effect_id_ref")
  end)
end

function TestConfigSanity:test_config_sanity_validate_rejects_missing_board_feedback_followup_sound_ref()
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

function TestConfigSanity:test_config_sanity_validate_rejects_missing_board_feedback_sound_ref()
  _with_runtime_ref_tables({
    cue = {
      sound_id_ref = "missing_sound",
    },
  }, {}, {}, function()
    _assert_validate_fails("board feedback cue references unknown sound_id_ref")
  end)
end

function TestConfigSanity:test_config_sanity_validate_is_cached_until_reset()
  config_sanity.reset_for_tests()
  lu.assertEvalToTrue(config_sanity.validate() == true, "first validate should pass on generated data")

  _with_runtime_ref_tables({
    cue = {
      effect_id_ref = "missing_effect",
    },
  }, {}, {}, function()
    lu.assertEvalToTrue(config_sanity.validate() == true, "validated cache should skip re-validating until reset")
    _assert_validate_fails("board feedback cue references unknown effect_id_ref")
  end)
end

function TestConfigSanity:test_all_items_have_prompt_style()
  local items = require("src.config.content.items")
  for _, item in ipairs(items) do
    lu.assertEvalToTrue(
      item.prompt_style == "alert" or item.prompt_style == "passive",
      "item " .. tostring(item.id) .. " missing or invalid prompt_style: " .. tostring(item.prompt_style)
    )
  end
end

function TestConfigSanity:test_no_item_description_references_removed_vehicle_subsystem()
  -- 座驾 (vehicle) subsystem was torn out (handoff: vehicle-teardown). Mine card 2005
  -- previously promised "摧毁座驾"; mine now uniformly hospitalizes. Pin that no item
  -- copy reintroduces the removed subsystem.
  local items = require("src.config.content.items")
  for _, item in ipairs(items) do
    for _, field in ipairs({ "name", "usage", "description" }) do
      local text = item[field]
      if type(text) == "string" then
        lu.assertEvalToTrue(
          text:find("座驾", 1, true) == nil,
          "item " .. tostring(item.id) .. " " .. field .. " must not reference the removed vehicle subsystem: " .. text
        )
      end
    end
  end
end

function TestConfigSanity:test_effect_group_only_on_specified_items()
  local items = require("src.config.content.items")
  local items_with_effect_group = {}
  for _, item in ipairs(items) do
    if item.effect_group ~= nil then
      table.insert(items_with_effect_group, item.id)
    end
  end
  lu.assertEvalToTrue(
    #items_with_effect_group == 2,
    "expected exactly 2 items with effect_group, got " .. #items_with_effect_group .. " items: " .. table.concat(items_with_effect_group, ", ")
  )
  local effect_groups_by_id = {}
  for _, item in ipairs(items) do
    if item.effect_group then
      effect_groups_by_id[item.id] = item.effect_group
    end
  end
  lu.assertEvalToTrue(effect_groups_by_id[2002] == "dice_control", "item 2002 should have effect_group=dice_control")
  lu.assertEvalToTrue(effect_groups_by_id[2003] == "dice_multiply", "item 2003 should have effect_group=dice_multiply")
end


return TestConfigSanity
