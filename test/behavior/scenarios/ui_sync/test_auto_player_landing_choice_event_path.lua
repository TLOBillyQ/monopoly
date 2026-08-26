local lu = require("luaunit")
local support = require("test.support.shared_support")
local fixtures = require("test.support.gameplay_fixtures")
local _config_reset = require("test.support.config_reset")

-- #524 时序裁定：开屏只允许发生在 dirty 刷新内；事件路径（on_need_choice）
-- 只记账（pending choice + ui_dirty）不开屏。本套件 pin 两条边界：
--   1. 事件触达时 modal.open_choice_modal 绝不被调（owner 类型无关）；
--   2. 同帧 dirty 刷新按 owner 门控开屏——auto/AI 不开，本地真人开。
local function _build_landing_choice(game)
  local owner_id = game.players[1].id
  return support.open_choice(game, {
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    title = "买地",
    body_lines = { "买地" },
    options = { { id = "buy_land", label = "买地" } },
    owner_role_id = owner_id,
    meta = {
      effect_ids = { "buy_land" },
      player_id = owner_id,
    },
  })
end

local function _run_choice_open_case(game_opts, expect_open, case_name)
  local game = support.new_game(game_opts)
  local state = fixtures.build_loop_state()
  support.prepare_board_scene(state, game)
  support.bind_ui_runtime(state)
  state.game = game

  local choice = _build_landing_choice(game)
  local modal = require("src.ui.coord.modal")
  local opened = false

  support.with_patches({
    {
      target = require("src.ui.coord.ui_runtime"),
      key = "render",
      value = function() end,
    },
    {
      target = modal,
      key = "open_choice_modal",
      value = function() opened = true end,
    },
    -- 本地身份经 client_role 表达(#341);「上一次点击者缓存」已随 #601 整体退役。
    {
      target = require("src.ui.render.support.runtime_ui"),
      key = "get_client_role",
      value = function()
        return { get_roleid = function() return game.players[1].id end }
      end,
    },
    -- owner 落在房间席位名册内,门控才放行(#444)。单字段 patch 而非
    -- runtime_ports.configure:后者整表替换,会清空同表其他端口。
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_roles",
      value = function()
        return { { get_roleid = function() return game.players[1].id end } }
      end,
    },
  }, function()
    local runtime_event_ports = require("src.ui.ports.events")
    runtime_event_ports.on_need_choice(state, function() return game end, { choice = choice })
    lu.assertFalse(opened, "event path must NOT open modal; it only records (#524): " .. case_name)
    lu.assertTrue(state.ui_dirty == true or require("src.ui.state.runtime").is_ui_dirty(state),
      "event path must mark ui_dirty so dirty refresh opens the modal: " .. case_name)

    local ui_model_sync = require("src.ui.ports.ui_sync")._model
    local common = {
      log_once = {},
      build_log_prefix = function()
        return ""
      end,
    }
    ui_model_sync.refresh_from_dirty(game, state, { any = true, ui = true }, common)
  end)

  if expect_open then
    lu.assertTrue(opened, "dirty refresh MUST open modal: " .. case_name)
  else
    lu.assertFalse(opened, "dirty refresh must NOT open modal: " .. case_name)
  end
end

TestAutoPlayerLandingChoiceEventPath = {}

function TestAutoPlayerLandingChoiceEventPath:setUp()
  _config_reset.reset_all()
end

-- 无 tearDown:席位名册经 with_patches 单字段 patch 铺设,出入两侧自动还原。

function TestAutoPlayerLandingChoiceEventPath:test_auto_player_landing_modal_opens_only_via_dirty_reconcile()
  _run_choice_open_case(
    { players = { "P1", "P2" }, auto_all = true, ai = {} },
    false,
    "auto/托管 owner: dirty refresh must NOT open"
  )
end

function TestAutoPlayerLandingChoiceEventPath:test_ai_player_landing_modal_opens_only_via_dirty_reconcile()
  _run_choice_open_case(
    { players = { "P1", "P2" }, ai = { [1] = true } },
    false,
    "AI owner: dirty refresh must NOT open"
  )
end

function TestAutoPlayerLandingChoiceEventPath:test_local_human_landing_modal_opens_only_via_dirty_reconcile()
  _run_choice_open_case(
    { players = { "P1", "P2" }, ai = {} },
    true,
    "local human owner: dirty refresh MUST open"
  )
end


return TestAutoPlayerLandingChoiceEventPath
