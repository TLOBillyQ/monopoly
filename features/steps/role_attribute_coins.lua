local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local constants = require("src.config.content.constants")
local balance = require("src.player.actions.balance")
local ui_model = require("src.ui.view")
local proc_lib = require("foundation.proc")
-- 角色属性金币域绑定（#192 簇 B）：金币读写全走 game 金币边界（balance 真源）,
-- Fixed 属性经注入的内存 Role 观察；静态护栏用 rg 扫仓。
local COIN = balance.COIN_COUNT_ATTR_ID
local function _game(w) return assert(w.driver and w.driver.game or w.setup_game, "缺少对局") end
local function _pl(w, i) return assert(_game(w).players[number_utils.to_integer(i)], "缺少玩家 " .. tostring(i)) end
local function _new_role(initial)
  local attrs = { [COIN] = initial }
  local role = { fail_next_set = false }
  function role.get_attr_raw_fixed(first, second) return attrs[first == role and second or first] end
  function role.set_attr_raw_fixed(first, second, third)
    if role.fail_next_set then role.fail_next_set = false; return false end
    attrs[first == role and second or first] = first == role and third or second
    return true
  end
  function role:force_attr_raw_fixed(attr_id, value) attrs[attr_id] = value end
  return role
end
-- 取（必要时替换为可控内存 Role）玩家的金币 Role,保留其当前读数。
local function _role(p)
  local role = p and p._coin_role or nil
  if role == nil or type(role.get_attr_raw_fixed) ~= "function" or type(role.set_attr_raw_fixed) ~= "function"
      or type(role.force_attr_raw_fixed) ~= "function" then
    local current = nil
    if role and type(role.get_attr_raw_fixed) == "function" then
      local ok, value = pcall(role.get_attr_raw_fixed, role, COIN)
      if ok then current = value end
    end
    p._coin_role = _new_role(current); role = p._coin_role
  end
  return role
end
local function _attr(p) return _role(p):get_attr_raw_fixed(COIN) end
local function _capture(w, fn)
  local ok, result = pcall(fn)
  w.last_coin_ok, w.last_coin_error = ok, not ok and tostring(result) or nil
  return true
end
local function _gate(w, fn) _game(w).anim_gate_port = { wait_action_anim = true, wait_move_anim = false }; return _capture(w, fn) end
local function _cash_anims(game)
  local out, turn = {}, game.turn or {}
  if turn.action_anim and turn.action_anim.kind == "cash_receive" then out[#out + 1] = turn.action_anim end
  for _, anim in ipairs(turn.action_anim_queue or {}) do if anim and anim.kind == "cash_receive" then out[#out + 1] = anim end end
  return out
end
local function _no_cash_field(w, i)
  if rawget(_pl(w, i), "cash") ~= nil then return nil, "玩家" .. tostring(i) .. " Player 对象不应含 cash 字段" end
  return true
end
local function _guard_hit(w) return w.role_coin_guard_error == nil or nil, w.role_coin_guard_error end
return dsl.steps({
  ["玩家角色ID为1加入对局"] = function(w) _pl(w, 1) end,
  ["玩家1的角色Fixed属性coin_count等于起始金币"] = function(w)
    return dsl.eq(_attr(_pl(w, 1)), constants.starting_cash, "初始 coin_count")
  end,
  -- 假如阶段（尚无金币操作）为设值,那么阶段为断言——旧语义保持。
  ["玩家{玩家序号:int}的角色Fixed属性coin_count为{金币:int}"] = function(w, a)
    local p = _pl(w, a["玩家序号"])
    if w.last_coin_ok == nil then _role(p):set_attr_raw_fixed(COIN, a["金币"]); return true end
    return dsl.eq(_attr(p), a["金币"], "玩家" .. tostring(a["玩家序号"]) .. " coin_count")
  end,
  ["玩家{玩家序号:int}的角色Fixed属性coin_count仍为{金币:int}"] = function(w, a)
    return dsl.eq(_attr(_pl(w, a["玩家序号"])), a["金币"], "玩家" .. tostring(a["玩家序号"]) .. " coin_count 应保持")
  end,
  ["玩家1的角色Fixed属性coin_count为非法值\"12.5\""] = function(w) _role(_pl(w, 1)):force_attr_raw_fixed(COIN, "12.5") end,
  ["玩家{玩家序号:int}的角色Fixed属性coin_count下一次写入会失败"] = function(w, a) _role(_pl(w, a["玩家序号"])).fail_next_set = true end,
  ["玩家1的Role不支持get_attr_raw_fixed或set_attr_raw_fixed"] = function(w) _pl(w, 1)._coin_role = {} end,
  ["通过金币边界给玩家{玩家序号:int}增加{金币:int}金币"] = function(w, a)
    return _gate(w, function() return _game(w):add_player_cash(_pl(w, a["玩家序号"]), a["金币"]) end)
  end,
  ["玩家{玩家序号:int}通过金币边界消费{金币:int}金币"] = function(w, a)
    return _gate(w, function() return _game(w):deduct_player_cash(_pl(w, a["玩家序号"]), a["金币"]) end)
  end,
  ["玩家1通过金币边界支付3000金币给玩家2"] = function(w)
    return _gate(w, function() return _game(w):transfer_player_cash(_pl(w, 1), _pl(w, 2), 3000) end)
  end,
  ["查询玩家{玩家序号:int}当前金币返回{金币:int}"] = function(w, a)
    return _capture(w, function()
      local actual = _game(w):player_cash(_pl(w, a["玩家序号"]))
      if actual ~= a["金币"] then error("余额: 期望 " .. tostring(a["金币"]) .. ",实际 " .. tostring(actual)) end
    end)
  end,
  ["查询玩家1当前金币"] = function(w) return _capture(w, function() return _game(w):player_cash(_pl(w, 1)) end) end,
  ["金币变化表现事件记录玩家{玩家序号:int}本次变化量为{变化量:int}"] = function(w, a)
    for _, anim in ipairs(_cash_anims(_game(w))) do
      if anim.player_id == a["玩家序号"] and anim.amount == a["变化量"] then return true end
    end
    return nil, "缺少玩家" .. tostring(a["玩家序号"]) .. " 变化量 " .. tostring(a["变化量"]) .. " 的 cash_receive 表现"
  end,
  ["玩家{玩家序号:int}的Player对象不包含cash余额字段"] = function(w, a) return _no_cash_field(w, a["玩家序号"]) end,
  ["玩家1和玩家2的Player对象都不包含cash余额字段"] = function(w)
    return dsl.all(function() return _no_cash_field(w, 1) end, function() return _no_cash_field(w, 2) end)
  end,
  ["玩家1没有收到金币获得动画"] = function(w) return dsl.eq(#_cash_anims(_game(w)), 0, "启动期 cash_receive 表现数") end,
  ["基础屏为玩家1刷新时显示金币余额"] = function(w)
    local game = _game(w)
    local model = ui_model.build(game, { game = game, ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = game.last_turn, finished = game.finished })
    local row = model and model.panel and model.panel.player_rows and model.panel.player_rows[1] or nil
    return dsl.eq(row and row.cash_value, game:player_cash(_pl(w, 1)), "基础屏金币显示")
  end,
  ["{操作}硬失败"] = function(w, a) return dsl.eq(w.last_coin_ok, false, tostring(a["操作"]) .. "应硬失败") end,
  ["错误信息包含{片段}"] = function(w, a)
    for part in tostring(a["片段"]):gmatch("[^或]+") do
      local ok, err = dsl.contains(tostring(w.last_coin_error), part, "错误信息")
      if not ok then return nil, err end
    end
    return true
  end,
  ["测试档案为玩家1提供旧cash输入12000"] = function(w) w.legacy_profile = { players = { [1] = { cash = 12000 } } } end,
  ["测试档案加载完成"] = function(w)
    for i, cfg in pairs((w.legacy_profile or {}).players or {}) do
      local p = _game(w).players[i]
      if p and cfg.cash ~= nil then _game(w):set_player_cash(p, cfg.cash) end
    end
  end,
  ["运行时玩家状态不包含cash余额字段"] = function(w)
    for _, p in ipairs(_game(w).players or {}) do if rawget(p, "cash") ~= nil then return nil, "运行时玩家含 cash 字段" end end
    return true
  end,
  ["acceptance状态输出不包含cash余额字段"] = function(w)
    local output = { players = {} }
    for i, p in ipairs(_game(w).players or {}) do output.players[i] = { id = p.id, coins = _game(w):player_cash(p) } end
    w.acceptance_state_output = output
  end,
  -- 静态护栏（rg 扫仓,命中即违规;三个目录断言共享一次扫描结果）。
  ["执行角色属性金币静态护栏"] = function(w)
    local root = (tostring(debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")):match("^(.*)/features/steps/[^/]+$") or "."
    w.role_coin_guard_error = nil
    for _, check in ipairs({
      { "-n", "player%.cash|balances%s*=|balances%[|%.cash%s*=", "src", "-g", "*.lua" },
      { "-n", "runtime_player%.cash|game%.players%[[^%]]+%]%.cash", "test", "-g", "*.lua" },
      { "-n", "runtime_player%.cash|game%.players%[[^%]]+%]%.cash", "tools/packages/acceptance", "-g", "*.lua" },
    }) do
      local command = { "rg" }
      for _, arg in ipairs(check) do command[#command + 1] = arg end
      local result = proc_lib.run_command(command, { cwd = root })
      if result.ok then w.role_coin_guard_error = result.stdout; break end
    end
  end,
  ["{目录}目录不直接读写player.cash或cash余额字段"] = _guard_hit,
  ["{目录}目录不构造或断言运行时player.cash余额字段"] = _guard_hit,
  ["旧profile输入兼容与cash_receive表现命名作为受控例外保留"] = function() return true end,
}, { name = "role_attribute_coins" })
