-- #293 批3 pin:src/ui/screens/skin_panel/skin_panel_state.lua 的幸存者:
-- 包装层(ensure_panel 调用、assert(panel, err or "missing_state") 与
-- 返回)的三处换 nil 变异。transaction_state 经 cosmetics port 转发代理
-- 取用,桩经 debug.setupvalue 直接替换 port 模块的 _impl upvalue(不依赖
-- compose_game 是否已装配,tearDown 原样还原)。

local lu = require("luaunit")
local cosmetics = require("src.ui.seams.cosmetics")

local _impl_upvalue_index = nil
do
  for i = 1, 10 do
    local name = debug.getupvalue(cosmetics.install, i)
    if name == "_impl" then
      _impl_upvalue_index = i
      break
    end
  end
end

local _saved_impl = nil
local _captured = nil

local function _set_impl(impl)
  debug.setupvalue(cosmetics.install, _impl_upvalue_index, impl)
end

TestSkinPanelState = {}

function TestSkinPanelState:setUp()
  _captured = {}
  -- debug.getupvalue 返回 (name, value) 两值,单赋值只取 name——必须显式
  -- 取第二返回值,否则 tearDown 会把 "_impl" 名字串写回,污染后续用例。
  local _, saved = debug.getupvalue(cosmetics.install, _impl_upvalue_index)
  _saved_impl = saved
  _set_impl({
    transaction_state = {
      ensure_panel = function(root_state)
        _captured.root = root_state
        if root_state == nil or root_state.ui == nil then
          return nil, "missing_state"
        end
        root_state.ui.skin_panel = root_state.ui.skin_panel or { open = false }
        return root_state.ui.skin_panel
      end,
    },
  })
end

function TestSkinPanelState:tearDown()
  _set_impl(_saved_impl)
end

function TestSkinPanelState:test_ensure_returns_the_panel_from_the_port()
  -- L6 ensure_panel 调用换 nil 与 L7 assert 调用换 nil:成功路径必须把
  -- port 返回的 panel 原样透出。
  local root_state = { ui = {} }
  local panel = require("src.ui.screens.skin_panel.skin_panel_state").ensure(root_state)
  lu.assertEvalToTrue(panel ~= nil, "ensure must return the panel")
  lu.assertEvalToTrue(panel == root_state.ui.skin_panel, "returned panel must be the recorded one")
  lu.assertEvalToTrue(_captured.root == root_state, "ensure must forward the root state")
end

function TestSkinPanelState:test_ensure_reuses_an_existing_panel()
  local existing = { open = true }
  local root_state = { ui = { skin_panel = existing } }
  local panel = require("src.ui.screens.skin_panel.skin_panel_state").ensure(root_state)
  lu.assertEvalToTrue(panel == existing, "existing panel must be reused, not replaced")
end

function TestSkinPanelState:test_ensure_raises_missing_state_without_ui()
  -- L7 `err or "missing_state"` 的 err 换 nil 等消息链在此钉死:无 ui 时
  -- 必须带 missing_state 语义报错。
  local ok, err = pcall(function()
    require("src.ui.screens.skin_panel.skin_panel_state").ensure({})
  end)
  lu.assertEvalToTrue(ok == false, "ensure must fail without ui state")
  lu.assertEvalToTrue(tostring(err):find("missing_state") ~= nil, "error must carry missing_state")
end

return TestSkinPanelState
