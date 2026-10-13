require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- Coverage for src.ui.screens.item_atlas: route specs, open/close/action handling.
-- Extends the existing paging tests in test_item_atlas_paging.lua which test
-- atlas_state pure logic.
local item_atlas = require("src.ui.screens.item_atlas")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local base_nodes = require("src.ui.schema.base")
local canvas = require("src.ui.coord.canvas_coordinator")

-- Minimal state stub used across tests. atlas_state.ensure() asserts state.ui.
local function _make_state(overrides)
  local s = {
    ui = overrides and overrides.ui or {},
    game = nil,
  }
  return s
end

-- Helper: set up atlas_state catalog for a reasonable default.
local function _setup_test_catalog()
  require("src.ui.screens.item_atlas.item_atlas_state").set_catalog({
    { id = "i1", name = "道具1" },
    { id = "i2", name = "道具2" },
    { id = "i3", name = "道具3" },
  })
end

-- Helper: stub game with dispatch_action.
local function _game_with_dispatch(dispatch_fn)
  return {
    dispatch_action = dispatch_fn or function() end,
  }
end

describe("TestItemAtlasBuildRouteSpecs", function()
do
  it("test_includes close, dismiss, prev, next, and per-card select actions", function()
    local specs = item_atlas.build_route_specs({})
    local action_names = {}
    local select_count = 0
    for _, s in ipairs(specs) do
      luassert.truthy(s.build_intent ~= nil, "each spec has a build_intent function")
      local intent = s.build_intent()
      if type(intent.action) == "string" then
        action_names[intent.action] = true
      elseif type(intent.action) == "table" and intent.action.type == "select" then
        select_count = select_count + 1
      end
    end
    luassert.truthy(action_names["close"], "has close action")
    luassert.truthy(action_names["dismiss"], "has dismiss action")
    luassert.truthy(action_names["prev"], "has prev action")
    luassert.truthy(action_names["next"], "has next action")
    luassert.truthy(select_count == #item_atlas_nodes.card_images, "one select spec per card slot")
  end)
end
end)

describe("TestItemAtlasOpenClose", function()
  local self
  before_each(function() self = {} end)
do
  before_each(function()
    _setup_test_catalog()
    -- Spy: intercept canvas.switch_by_role_id to verify call arguments.
    -- This kills --mutate and→or on `state and state.ui` and
    -- --mutate or→and on `role_id or atlas.role_id`(open/close 的 canvas 调用)。
    -- Save original to restore in after_each; mutation driver runs all suites
    -- in one process, so a permanent override would break other spec files.
    self._canvas_called_with = nil
    self._orig_switch_by_role_id = canvas.switch_by_role_id
    canvas.switch_by_role_id = function(ui, target, role_id)
      self._canvas_called_with = { ui = ui, target = target, role_id = role_id }
    end
  end)

  after_each(function()
    require("src.ui.screens.item_atlas.item_atlas_state").set_catalog(nil)
    canvas.switch_by_role_id = self._orig_switch_by_role_id
  end)

  it("test_open() passes state.ui and role_id to canvas", function()
    local state = _make_state()
    item_atlas.open(state, "roleA")
    luassert.truthy(self._canvas_called_with ~= nil, "canvas.switch_by_role_id was called")
    -- Regression for --mutate and→or on `state and state.ui` (L90):
    -- the first arg must be state.ui, not state (which 'or' would return).
    luassert.truthy(self._canvas_called_with.ui == state.ui, "canvas receives state.ui, not state")
    luassert.truthy(self._canvas_called_with.target == item_atlas_nodes.canvas, "switches to item_atlas canvas")
    luassert.truthy(self._canvas_called_with.role_id == "roleA", "role_id passed through")
  end)

  it("test_close() with nil role_id falls back to atlas.role_id for canvas call", function()
    -- Regression for --mutate or→and on `role_id or atlas.role_id` (L100):
    -- with nil role_id, original passes atlas.role_id; mutant passes nil.
    local state = _make_state()
    item_atlas.open(state, "roleB")
    -- Reset spy, open() already called canvas.
    self._canvas_called_with = nil
    item_atlas.close(state, nil)
    luassert.truthy(self._canvas_called_with ~= nil, "canvas.switch_by_role_id was called on close")
    -- Regression for --mutate and→or on `state and state.ui` (L100):
    -- the first arg must be state.ui, not state.
    luassert.truthy(self._canvas_called_with.ui == state.ui, "canvas receives state.ui, not state")
    luassert.truthy(self._canvas_called_with.target == base_nodes.canvas, "switches to base canvas")
    luassert.truthy(self._canvas_called_with.role_id == "roleB",
      "role_id falls back to atlas.role_id when nil is passed")
  end)

  it("test_close() with explicit role_id passes it to canvas", function()
    local state = _make_state()
    item_atlas.open(state, "roleX")
    self._canvas_called_with = nil
    item_atlas.close(state, "roleY")
    luassert.truthy(self._canvas_called_with.role_id == "roleY",
      "explicit role_id is used, not stored atlas.role_id")
  end)

  -- #583:关屏必须清理放大覆盖层(选中态 + 三节点 per-role 显隐)——否则任何
  -- 关屏路径(手动关、interrupt、旁观者回屏)之后图鉴 canvas 再显示时复活
  -- 陈旧放大卡。翻页/点空白/open 都有同等清理,close 是唯一漏网路径。
  -- 观测可见行为:ui.set_visible 捕获三节点终态,不钉内部调用。
  it("test_close() clears selection and hides enlarged overlay", function()
    local vis = {}
    local state = _make_state({ ui = {
      set_visible = function(_, name, v) vis[name] = v == true end,
      set_touch_enabled = function() end,
    } })
    item_atlas.open(state, "roleA")
    item_atlas.handle_action(state, { type = "select", slot_index = 1 }, "roleA")
    luassert.truthy(state.ui.item_atlas.selected_item_id ~= nil,
      "slot select should mark a selection before close")
    -- 测试环境无贴图 refs,show_enlarged 不推可见性;直接置捕获态模拟宿主侧
    -- 覆盖层正可见(与真机「选中后三节点可见」同形态)。
    vis[item_atlas_nodes.enlarged_card] = true
    vis[item_atlas_nodes.close_hint_label] = true
    vis[item_atlas_nodes.close_blank] = true

    item_atlas.close(state, "roleA")

    luassert.truthy(state.ui.item_atlas.selected_item_id == nil,
      "close should clear the selected item")
    for _, node in ipairs({ item_atlas_nodes.enlarged_card, item_atlas_nodes.close_hint_label, item_atlas_nodes.close_blank }) do
      luassert.truthy(vis[node] == false, node .. " should be hidden on close")
    end
  end)
end
end)

describe("TestItemAtlasHandler", function()
do
  it("test_handle_action with dismiss never dispatches action_anim_done", function()
    -- #543:图鉴放大卡回归纯浏览用途,dismiss 不再向回合机派发 action_anim_done。
    local dispatched
    local state = _make_state()
    state.game = _game_with_dispatch(function(_, action)
      dispatched = action
    end)
    state.game.turn = { action_anim = { kind = "item_gain_popup", seq = 42, owner_role_id = "roleC" } }
    item_atlas.handle_action(state, "dismiss", "roleC")
    luassert.truthy(dispatched == nil, "dismiss must not dispatch action_anim_done")
  end)
end

-- 等价变异体说明：
-- L40 "ui.item_atlas" → nil, L93 "图鉴已打开" → nil, L101 "已关闭" → nil,
-- L101 "item_atlas:close" → nil — 均属 panel_tip 通知文字/key,不改变可观测行为。
-- L174 atlas_state.catalog() → nil — 模块级 init,变异框架对顶层表达式的
--   替换受 module cache 影响无法正确隔离(mutate4lua 已知限)。


end)
