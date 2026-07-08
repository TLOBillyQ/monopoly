-- 选择屏注册表：每个 Screen 深模块 require 时自注册，共享派发/工厂表
-- (node_ops.build_choice_screens / choice_openers._screen_openers /
--  routes.canvas_builders / choice_helpers.screen_canvases) 统一向此委托。
-- 引入此 seam 后，新增/迁移一个屏只动它自己的文件 + 下方 require 清单，
-- 屏与屏之间零重叠写 —— 这是「逐屏并行」成立的前提。
--
-- 为避免 registry 与各 Screen 模块在 require 期互相等待，本模块不主动 `_load_all`；
-- 首次调用任意聚合 API 时才惰性加载清单中的屏模块，此时 registry 已就绪。
local registry = {}

local _screens = {}       -- 按注册序保留（route spec 拼接需保序）
local _by_key = {}
local _loaded = false

function registry.register(screen)
  assert(type(screen) == "table" and type(screen.key) == "string", "screen needs a string key")
  assert(_by_key[screen.key] == nil, "duplicate screen key: " .. screen.key)
  _screens[#_screens + 1] = screen
  _by_key[screen.key] = screen
end

-- 强制加载所有屏模块（它们在 require 时自注册）。清单是唯一的 append-only 共享点。
local function _ensure_loaded()
  if _loaded then
    return
  end
  _loaded = true
  require("src.ui.screens.target_choice")
  -- Task 2 追加：require("src.ui.screens.remote_choice")
  -- Phase B 追加：player_choice / secondary_confirm
end

function registry.build_choice_screens()
  _ensure_loaded()
  local out = {}
  for _, s in ipairs(_screens) do
    out[s.key] = s.descriptor()
  end
  return out
end

function registry.opener_for(key)
  _ensure_loaded()
  local s = _by_key[key]
  return s and s.open or nil
end

function registry.canvas_for(key)
  _ensure_loaded()
  local s = _by_key[key]
  return s and s.canvas or nil
end

function registry.build_route_specs(state)
  _ensure_loaded()
  local specs = {}
  for _, s in ipairs(_screens) do
    if s.build_route_specs then
      for _, spec in ipairs(s.build_route_specs(state) or {}) do
        specs[#specs + 1] = spec
      end
    end
  end
  return specs
end

return registry
