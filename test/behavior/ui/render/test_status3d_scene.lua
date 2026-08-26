-- status3d/scene 直驱规约(#262 幸存闭合):warn_once 载荷与 cache 键、
-- ensure_layers_for_player 的返回值三态(成功 true / 已建 true / 失败 false)、
-- layer 初始可见性 false、meta 失败时 disabled 置位。
-- 高层行为(状态文本/优先级)由 action_status/status3d_spec 覆盖,这里只钉
-- scene 模块自身的失败路径与载荷。


local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local luax = require("test.support.luax")
local scene = require("src.ui.render.status3d.scene")
local specs = require("src.ui.render.status3d.specs")
local meta = require("src.ui.render.status3d.meta")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local logger = require("src.foundation.log")

local _STATUS_COUNT = 6

local function _new_cache()
  return {
    layers = {},
    text_nodes = {},
    last_status_key_by_player = {},
    warned_once = {},
    disabled = false,
    meta = nil,
  }
end

-- deps.host_runtime 直桩:resolve_role_with 应用谓词,visible 调用全捕获。
local function _make_env(opts)
  opts = opts or {}
  local env = { warns = {}, visible_calls = {} }
  local role = opts.role
  env.deps = {
    host_runtime = {
      resolve_role_with = function(_, predicate)
        if role == nil then
          return nil
        end
        if predicate and not predicate(role) then
          return nil
        end
        return role
      end,
      has_scene_ui_support = function()
        return true
      end,
      set_scene_ui_visible = function(layer, observer, visible)
        env.visible_calls[#env.visible_calls + 1] = { layer = layer, visible = visible }
      end,
      get_eui_node_at_scene_ui = function(_, node_id)
        return "text_node_" .. tostring(node_id)
      end,
    },
  }
  env.patches = {
    { key = "Enums", value = { ModelSocket = { socket_head = 1 } } },
    { key = "UIManager", value = {
      get_first_node_by_name = opts.get_first_node_by_name or function(_)
        return { id = 42 }
      end,
    } },
    { target = logger, key = "warn", value = function(...)
      env.warns[#env.warns + 1] = { ... }
    end },
    { target = runtime_ports, key = "resolve_roles", value = function()
      return { { id = "observer" } }
    end },
  }
  return env
end

local function _has_warn(env, expected)
  for _, warn in ipairs(env.warns) do
    local matched = true
    for index, value in ipairs(expected) do
      if warn[index] ~= value then
        matched = false
        break
      end
    end
    if matched and #warn == #expected then
      return true
    end
  end
  return false
end

local function _make_role_with_ctrl_unit(create_result)
  return {
    get_ctrl_unit = function()
      return {
        create_scene_ui_bind_unit = function(layout_id)
          if create_result == nil then
            return nil
          end
          return "layer_" .. tostring(layout_id)
        end,
      }
    end,
  }
end

TestStatus3dScene = {}

-- status3d scene failure paths (#262)
function TestStatus3dScene:test_missing_role_warns_with_payload_and_returns_false()
  local env = _make_env({ role = nil })
  local cache = _new_cache()
  local result
  _with_patches(env.patches, function()
    result = scene.ensure_layers_for_player(cache, { id = 1 }, env.deps)
  end)
  _assert_eq(result, false, "missing role must fail")
  _assert_eq(_has_warn(env, { "status3d missing role:", "1" }), true,
    "warn must carry the missing-role label and player id")
  _assert_eq(cache.warned_once["missing_role_1"], true, "warn-once key must include the player id")
end

function TestStatus3dScene:test_ctrl_unit_without_create_scene_ui_bind_unit_warns_and_returns_false()
  local env = _make_env({
    role = {
      get_ctrl_unit = function()
        return {}
      end,
    },
  })
  local cache = _new_cache()
  local result
  _with_patches(env.patches, function()
    result = scene.ensure_layers_for_player(cache, { id = 2 }, env.deps)
  end)
  _assert_eq(result, false, "missing create_scene_ui_bind_unit must fail")
  _assert_eq(_has_warn(env, { "status3d unit missing create_scene_ui_bind_unit:", "2" }), true,
    "warn must carry the missing-method label and player id")
  _assert_eq(cache.warned_once["missing_ctrl_unit_2"], true, "warn-once key must include the player id")
end

function TestStatus3dScene:test_layer_creation_failure_warns_per_status_but_still_succeeds()
  local env = _make_env({ role = _make_role_with_ctrl_unit(nil) })
  local cache = _new_cache()
  local result
  _with_patches(env.patches, function()
    result = scene.ensure_layers_for_player(cache, { id = 3 }, env.deps)
  end)
  _assert_eq(result, true, "layer creation failure must not fail the whole ensure")
  _assert_eq(_has_warn(env, { "status3d create layer failed:", "hospital", "3" }), true,
    "warn must carry the failure label, status key, and player id")
  _assert_eq(cache.warned_once["create_layer_hospital_3"], true,
    "warn-once key must combine status key and player id")
end

function TestStatus3dScene:test_missing_remaining_text_node_warns_and_leaves_text_node_unset()
  local env = _make_env({
    role = _make_role_with_ctrl_unit("layer"),
    get_first_node_by_name = function()
      return nil
    end,
  })
  local cache = _new_cache()
  local result
  _with_patches(env.patches, function()
    result = scene.ensure_layers_for_player(cache, { id = 4 }, env.deps)
  end)
  _assert_eq(result, true, "missing text node must not fail the whole ensure")
  _assert_eq(_has_warn(env, { "status3d missing remaining-text node:", "hospital", "4" }), true,
    "warn must carry the missing-node label, status key, and player id")
  _assert_eq(cache.warned_once["missing_text_node_hospital_4"], true,
    "warn-once key must combine status key and player id")
  _assert_eq(next(cache.text_nodes[4]), nil, "no text node should be recorded")
end

function TestStatus3dScene:test_success_hides_layers_for_observers_returns_true_and_short_circuits_on_repeat()
  local env = _make_env({ role = _make_role_with_ctrl_unit("layer") })
  local cache = _new_cache()
  local first
  local second
  _with_patches(env.patches, function()
    first = scene.ensure_layers_for_player(cache, { id = 5 }, env.deps)
    second = scene.ensure_layers_for_player(cache, { id = 5 }, env.deps)
  end)
  _assert_eq(first, true, "a successful ensure must return true")
  _assert_eq(second, true, "an already-cached ensure must return true")
  _assert_eq(#env.visible_calls, _STATUS_COUNT, "repeat ensure must not re-hide layers")
  for index, call in ipairs(env.visible_calls) do
    _assert_eq(call.visible, false, "layer " .. index .. " must start hidden for observers")
  end
  _assert_eq(cache.last_status_key_by_player[5], specs.INIT_STATUS, "status must initialize")
  _assert_eq(next(cache.text_nodes[5]) ~= nil, true, "text nodes should be recorded")
end

function TestStatus3dScene:test_bind_unit_creation_passes_socket_offset_and_flags()
  -- L42 create_scene_ui_bind_unit 实参链(offset、-1.0、true、true 的换 nil/
  -- 删负号/true->false 变异):绑定单位必须收到头部 socket、上方偏移、
  -- 负 z 序号与双开 flag。
  local captured = nil
  local env = _make_env({
    role = {
      get_ctrl_unit = function()
        return {
          create_scene_ui_bind_unit = function(layout_id, socket, offset, z_index, visible, interactable)
            captured = {
              layout_id = layout_id, socket = socket, offset = offset,
              z_index = z_index, visible = visible, interactable = interactable,
            }
            return "layer_ok"
          end,
        }
      end,
    },
  })
  local cache = _new_cache()
  local result
  _with_patches(env.patches, function()
    result = scene.ensure_layers_for_player(cache, { id = 7 }, env.deps)
  end)
  _assert_eq(result, true, "bind unit creation must succeed")
  _assert_eq(captured ~= nil, true, "create_scene_ui_bind_unit must be called")
  _assert_eq(captured.socket, 1, "bind unit must use the head socket")
  _assert_eq(captured.offset.x, 0.0, "bind unit offset x")
  _assert_eq(captured.offset.y, 4.0, "bind unit offset y")
  _assert_eq(captured.z_index, -1.0, "bind unit z index")
  _assert_eq(captured.visible, true, "bind unit visible flag")
  _assert_eq(captured.interactable, true, "bind unit interactable flag")
end

function TestStatus3dScene:test_meta_resolve_failure_warns_disables_the_cache_and_returns_false()
  local env = _make_env({ role = _make_role_with_ctrl_unit("layer") })
  env.patches[#env.patches + 1] = { target = specs, key = "get_layout_id", value = function()
    return nil
  end }
  local cache = _new_cache()
  local result
  _with_patches(env.patches, function()
    result = scene.ensure_layers_for_player(cache, { id = 6 }, env.deps)
  end)
  _assert_eq(result, false, "meta failure must fail the ensure")
  _assert_eq(cache.disabled, true, "meta failure must disable the cache")
  _assert_eq(cache.warned_once["meta_error"], true, "warn-once key must be meta_error")
  local warn = env.warns[1]
  _assert_eq(warn[1], "status3d meta resolve failed:", "warn must carry the meta failure label")
  _assert_eq(type(warn[2]), "string", "warn must carry the meta error detail")
end

function TestStatus3dScene:test_ensure_cache_asserts_descriptive_error_on_missing_state()
  -- 杀 status3d/meta L7 "missing state" 消息钉:ensure_cache(nil) 必须报带
  -- 消息的错,消息->nil 变异后无消息会露馅。
  luax.has_error(function()
    meta.ensure_cache(nil)
  end, "missing state")
end


return TestStatus3dScene
