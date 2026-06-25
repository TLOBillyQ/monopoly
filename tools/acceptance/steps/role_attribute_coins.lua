local number_utils = require("src.foundation.number")
local constants = require("src.config.content.constants")
local fan_club = require("src.app.host_integrations.fan_club")
local balance = require("src.player.actions.balance")
local profile_bootstrap = require("src.app.profile_bootstrap")
local ui_model = require("src.ui.view")
local common = require("shared.lib.common")

local role_attribute_coins_steps = {}

local COIN_COUNT_ATTR_ID = balance.COIN_COUNT_ATTR_ID

local function _game(world)
  return world.driver and world.driver.game or world.setup_game
end

local function _player(world, index)
  local game = assert(_game(world), "missing game")
  return assert(game.players[number_utils.to_integer(index)], "missing player " .. tostring(index))
end

local function _new_role(initial)
  local attrs = {
    [COIN_COUNT_ATTR_ID] = initial,
  }
  local role = {
    fail_next_set = false,
  }
  function role.get_attr_raw_fixed(first, second)
    local attr_id = first == role and second or first
    return attrs[attr_id]
  end
  function role.set_attr_raw_fixed(first, second, third)
    local attr_id = first == role and second or first
    local value = first == role and third or second
    if role.fail_next_set == true then
      role.fail_next_set = false
      return false
    end
    attrs[attr_id] = value
    return true
  end
  function role:force_attr_raw_fixed(attr_id, value)
    attrs[attr_id] = value
  end
  return role
end

local function _install_role(player, value)
  player._coin_role = _new_role(value)
  return player._coin_role
end

local function _role(player)
  local role = player and player._coin_role or nil
  if role == nil or type(role.get_attr_raw_fixed) ~= "function"
      or type(role.set_attr_raw_fixed) ~= "function"
      or type(role.force_attr_raw_fixed) ~= "function" then
    local current = nil
    if role and type(role.get_attr_raw_fixed) == "function" then
      local ok, value = pcall(role.get_attr_raw_fixed, role, COIN_COUNT_ATTR_ID)
      if ok then
        current = value
      end
    end
    role = _install_role(player, current)
  end
  return role
end

local function _attr(player)
  return _role(player):get_attr_raw_fixed(COIN_COUNT_ATTR_ID)
end

local function _parse_amount(example, key)
  local amount = number_utils.to_integer(example[key])
  if amount == nil then
    return nil, "invalid " .. tostring(key) .. ": " .. tostring(example[key])
  end
  return amount
end

local function _capture_result(world, fn)
  local ok, a, b = pcall(fn)
  world.last_coin_ok = ok
  if ok then
    world.last_coin_error = nil
    world.last_coin_result = a
    world.last_coin_result_2 = b
    return true
  end
  world.last_coin_error = tostring(a)
  return true
end

local function _all_cash_anims(game)
  local out = {}
  local turn = game.turn or {}
  if turn.action_anim and turn.action_anim.kind == "cash_receive" then
    out[#out + 1] = turn.action_anim
  end
  for _, anim in ipairs(turn.action_anim_queue or {}) do
    if anim and anim.kind == "cash_receive" then
      out[#out + 1] = anim
    end
  end
  return out
end

local function _contains(text, fragment)
  return tostring(text or ""):find(tostring(fragment), 1, true) ~= nil
end

local function _project_root()
  local src_path = debug.getinfo(1, "S").source or "@tools/acceptance/steps/role_attribute_coins.lua"
  local normalized = tostring(src_path):gsub("^@", ""):gsub("\\", "/")
  local tools_dir = normalized:match("^(.*)/acceptance/steps/role_attribute_coins%.lua$")
  if tools_dir == nil then
    return "."
  end
  return tools_dir:match("^(.*)/tools$") or "."
end

local function _run_rg(root, args)
  local command = { "rg" }
  for _, arg in ipairs(args) do
    command[#command + 1] = arg
  end
  return common.run_command(command, { cwd = root })
end

local function _guard_src(root)
  local result = _run_rg(root, {
    "-n", "player%.cash|balances%s*=|balances%[|%.cash%s*=",
    "src", "-g", "*.lua",
    "-g", "!src/app/profile_bootstrap.lua",
  })
  if result.ok then
    return nil, result.stdout
  end
  return true
end

local function _guard_tests(root, path)
  local result = _run_rg(root, {
    "-n", "runtime_player%.cash|game%.players%[[^%]]+%]%.cash",
    path, "-g", "*.lua",
  })
  if result.ok then
    return nil, result.stdout
  end
  return true
end

local function _set_or_assert_attr(world, player_index, expected)
  local player = _player(world, player_index)
  if world.last_coin_ok == nil then
    _role(player):set_attr_raw_fixed(COIN_COUNT_ATTR_ID, expected)
    return true
  end
  local actual = _attr(player)
  if actual ~= expected then
    return nil, "expected attr " .. tostring(expected) .. ", got " .. tostring(actual)
  end
  return true
end

local function _assert_attr(world, player_index, expected)
  local actual = _attr(_player(world, player_index))
  if actual ~= expected then
    return nil, "expected attr " .. tostring(expected) .. ", got " .. tostring(actual)
  end
  return true
end

local function _assert_attr_still(world, player_index, expected)
  local actual = _attr(_player(world, player_index))
  if actual ~= expected then
    return nil, "expected attr still " .. tostring(expected) .. ", got " .. tostring(actual)
  end
  return true
end

local function _add_coins(world, player_index, amount)
  local game = _game(world)
  game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  return _capture_result(world, function()
    return game:add_player_cash(_player(world, player_index), amount)
  end)
end

local function _spend_coins(world, player_index, amount)
  local game = _game(world)
  game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  return _capture_result(world, function()
    return game:deduct_player_cash(_player(world, player_index), amount)
  end)
end

local function _assert_balance(world, player_index, expected)
  return _capture_result(world, function()
    local actual = _game(world):player_balance(_player(world, player_index), "金币")
    if actual ~= expected then
      error("expected balance " .. tostring(expected) .. ", got " .. tostring(actual))
    end
    return actual
  end)
end

local function _assert_cash_anim(world, player_index, expected)
  for _, anim in ipairs(_all_cash_anims(_game(world))) do
    if anim.player_id == player_index and anim.amount == expected then
      return true
    end
  end
  return nil, "missing cash_receive anim for player " .. tostring(player_index)
    .. " amount " .. tostring(expected)
end

local function _assert_player_has_no_cash(world, player_index)
  local player = _player(world, player_index)
  if rawget(player, "cash") ~= nil then
    return nil, "player has cash field"
  end
  return true
end

function role_attribute_coins_steps.handlers()
  return {
    ["玩家角色ID为1加入对局"] = function(world)
      _player(world, 1)
      return true
    end,

    ["玩家1的角色Fixed属性coin_count等于起始金币与粉丝团起始金币加成之和"] = function(world)
      local expected = constants.starting_cash + (fan_club.starting_cash_bonus() or 0)
      local actual = _attr(_player(world, 1))
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家1的角色Fixed属性coin_count为1000"] = function(world)
      return _set_or_assert_attr(world, 1, 1000)
    end,

    ["玩家1的角色Fixed属性coin_count为10000"] = function(world)
      return _set_or_assert_attr(world, 1, 10000)
    end,

    ["玩家2的角色Fixed属性coin_count为2000"] = function(world)
      return _set_or_assert_attr(world, 2, 2000)
    end,

    ["玩家1的角色Fixed属性coin_count为12000"] = function(world)
      return _assert_attr(world, 1, 12000)
    end,

    ["玩家1的角色Fixed属性coin_count为1500"] = function(world)
      return _assert_attr(world, 1, 1500)
    end,

    ["玩家1的角色Fixed属性coin_count为5000"] = function(world)
      return _assert_attr(world, 1, 5000)
    end,

    ["玩家1的角色Fixed属性coin_count为7000"] = function(world)
      return _assert_attr(world, 1, 7000)
    end,

    ["玩家2的角色Fixed属性coin_count为5000"] = function(world)
      return _assert_attr(world, 2, 5000)
    end,

    ["玩家1的角色Fixed属性coin_count仍为10000"] = function(world)
      return _assert_attr_still(world, 1, 10000)
    end,

    ["玩家2的角色Fixed属性coin_count仍为2000"] = function(world)
      return _assert_attr_still(world, 2, 2000)
    end,

    ["玩家1的Player对象不包含cash余额字段"] = function(world)
      return _assert_player_has_no_cash(world, 1)
    end,

    ["通过金币边界给玩家1增加500金币"] = function(world)
      return _add_coins(world, 1, 500)
    end,

    ["玩家1通过金币边界消费5000金币"] = function(world)
      return _spend_coins(world, 1, 5000)
    end,

    ["查询玩家1当前金币返回1500"] = function(world)
      return _assert_balance(world, 1, 1500)
    end,

    ["查询玩家1当前金币返回5000"] = function(world)
      return _assert_balance(world, 1, 5000)
    end,

    ["查询玩家1当前金币返回12000"] = function(world)
      return _assert_balance(world, 1, 12000)
    end,

    ["金币变化表现事件记录玩家1本次变化量为500"] = function(world)
      return _assert_cash_anim(world, 1, 500)
    end,

    ["金币变化表现事件记录玩家1本次变化量为-5000"] = function(world)
      return _assert_cash_anim(world, 1, -5000)
    end,

    ["金币变化表现事件记录玩家1本次变化量为-3000"] = function(world)
      return _assert_cash_anim(world, 1, -3000)
    end,

    ["金币变化表现事件记录玩家2本次变化量为3000"] = function(world)
      return _assert_cash_anim(world, 2, 3000)
    end,

    ["玩家1的角色Fixed属性coin_count为非法值\"12.5\""] = function(world)
      _role(_player(world, 1)):force_attr_raw_fixed(COIN_COUNT_ATTR_ID, "12.5")
      return true
    end,

    ["玩家2的角色Fixed属性coin_count下一次写入会失败"] = function(world)
      _role(_player(world, 2)).fail_next_set = true
      return true
    end,

    ["玩家<玩家序号>的角色Fixed属性coin_count为非法值\"<非法值>\""] = function(world, example)
      _role(_player(world, example["玩家序号"])):force_attr_raw_fixed(COIN_COUNT_ATTR_ID, example["非法值"])
      return true
    end,

    ["玩家<玩家序号>的角色Fixed属性coin_count下一次写入会失败"] = function(world, example)
      _role(_player(world, example["玩家序号"])).fail_next_set = true
      return true
    end,

    ["玩家1的Role不支持get_attr_raw_fixed或set_attr_raw_fixed"] = function(world)
      _player(world, 1)._coin_role = {}
      return true
    end,

    ["通过金币边界给玩家<玩家序号>增加<金币>金币"] = function(world, example)
      local game = _game(world)
      local amount, err = _parse_amount(example, "金币")
      if amount == nil then return nil, err end
      game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
      return _capture_result(world, function()
        return game:add_player_cash(_player(world, example["玩家序号"]), amount)
      end)
    end,

    ["玩家<玩家序号>通过金币边界消费<金币>金币"] = function(world, example)
      local game = _game(world)
      local amount, err = _parse_amount(example, "金币")
      if amount == nil then return nil, err end
      game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
      return _capture_result(world, function()
        return game:deduct_player_cash(_player(world, example["玩家序号"]), amount)
      end)
    end,

    ["玩家1通过金币边界支付3000金币给玩家2"] = function(world)
      local game = _game(world)
      game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
      return _capture_result(world, function()
        return game:transfer_player_cash(_player(world, 1), _player(world, 2), 3000)
      end)
    end,

    ["查询玩家<玩家序号>当前金币返回<金币>"] = function(world, example)
      local expected, err = _parse_amount(example, "金币")
      if expected == nil then return nil, err end
      return _capture_result(world, function()
        local actual = _game(world):player_balance(_player(world, example["玩家序号"]), "金币")
        if actual ~= expected then
          error("expected balance " .. tostring(expected) .. ", got " .. tostring(actual))
        end
        return actual
      end)
    end,

    ["查询玩家1当前金币"] = function(world)
      return _capture_result(world, function()
        return _game(world):player_balance(_player(world, 1), "金币")
      end)
    end,

    ["玩家<玩家序号>的角色Fixed属性coin_count等于<金币>"] = function(world, example)
      local expected, err = _parse_amount(example, "金币")
      if expected == nil then return nil, err end
      local actual = _attr(_player(world, example["玩家序号"]))
      if actual ~= expected then
        return nil, "expected attr " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家<玩家序号>的角色Fixed属性coin_count为<金币>"] = function(world, example)
      local expected, err = _parse_amount(example, "金币")
      if expected == nil then return nil, err end
      local player = _player(world, example["玩家序号"])
      if world.last_coin_ok == nil then
        _role(player):set_attr_raw_fixed(COIN_COUNT_ATTR_ID, expected)
        return true
      end
      local actual = _attr(player)
      if actual ~= expected then
        return nil, "expected attr " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家<玩家序号>的角色Fixed属性coin_count仍为<金币>"] = function(world, example)
      local expected, err = _parse_amount(example, "金币")
      if expected == nil then return nil, err end
      local actual = _attr(_player(world, example["玩家序号"]))
      if actual ~= expected then
        return nil, "expected attr still " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["金币变化表现事件记录玩家<玩家序号>本次变化量为<变化量>"] = function(world, example)
      local player_index = number_utils.to_integer(example["玩家序号"])
      local expected, err = _parse_amount(example, "变化量")
      if expected == nil then return nil, err end
      for _, anim in ipairs(_all_cash_anims(_game(world))) do
        if anim.player_id == player_index and anim.amount == expected then
          return true
        end
      end
      return nil, "missing cash_receive anim for player " .. tostring(player_index)
        .. " amount " .. tostring(expected)
    end,

    ["玩家<玩家序号>的Player对象不包含cash余额字段"] = function(world, example)
      local player = _player(world, example["玩家序号"])
      if rawget(player, "cash") ~= nil then
        return nil, "player has cash field"
      end
      return true
    end,

    ["玩家1和玩家2的Player对象都不包含cash余额字段"] = function(world)
      for index = 1, 2 do
        if rawget(_player(world, index), "cash") ~= nil then
          return nil, "player " .. tostring(index) .. " has cash field"
        end
      end
      return true
    end,

    ["玩家1没有收到金币获得动画"] = function(world)
      if #_all_cash_anims(_game(world)) ~= 0 then
        return nil, "startup queued cash_receive anim"
      end
      return true
    end,

    ["基础屏为玩家1刷新时显示金币余额"] = function(world)
      local game = _game(world)
      local model = ui_model.build(game, {
        game = game,
        ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
        last_turn = game.last_turn,
        finished = game.finished,
      })
      local row = model and model.panel and model.panel.player_rows and model.panel.player_rows[1] or nil
      local expected = game:player_balance(_player(world, 1), "金币")
      if not row or row.cash_value ~= expected then
        return nil, "expected panel cash " .. tostring(expected)
      end
      return true
    end,

    ["本次金币支付硬失败"] = function(world)
      if world.last_coin_ok ~= false then
        return nil, "expected payment failure"
      end
      return true
    end,

    ["金币读取硬失败"] = function(world)
      if world.last_coin_ok ~= false then
        return nil, "expected read failure"
      end
      return true
    end,

    ["金币写入硬失败"] = function(world)
      if world.last_coin_ok ~= false then
        return nil, "expected write failure"
      end
      return true
    end,

    ["错误信息包含玩家1"] = function(world)
      if not _contains(world.last_coin_error, "玩家1") then
        return nil, "error missing 玩家1: " .. tostring(world.last_coin_error)
      end
      return true
    end,

    ["错误信息包含玩家2"] = function(world)
      if not _contains(world.last_coin_error, "玩家2") then
        return nil, "error missing 玩家2: " .. tostring(world.last_coin_error)
      end
      return true
    end,

    ["错误信息包含coin_count"] = function(world)
      if not _contains(world.last_coin_error, COIN_COUNT_ATTR_ID) then
        return nil, "error missing coin_count: " .. tostring(world.last_coin_error)
      end
      return true
    end,

    ["错误信息包含回滚结果"] = function(world)
      if not _contains(world.last_coin_error, "回滚结果") then
        return nil, "error missing rollback result: " .. tostring(world.last_coin_error)
      end
      return true
    end,

    ["错误信息包含有限整数"] = function(world)
      if not _contains(world.last_coin_error, "有限整数") then
        return nil, "error missing finite integer: " .. tostring(world.last_coin_error)
      end
      return true
    end,

    ["错误信息包含get_attr_raw_fixed或set_attr_raw_fixed"] = function(world)
      if not _contains(world.last_coin_error, "get_attr_raw_fixed")
          or not _contains(world.last_coin_error, "set_attr_raw_fixed") then
        return nil, "error missing attr method names: " .. tostring(world.last_coin_error)
      end
      return true
    end,

    ["测试档案为玩家1提供旧cash输入12000"] = function(world)
      world.legacy_profile = {
        players = {
          [1] = { cash = 12000 },
        },
      }
      return true
    end,

    ["测试档案加载完成"] = function(world)
      profile_bootstrap.apply_bootstrap(_game(world), world.legacy_profile or {})
      return true
    end,

    ["运行时玩家状态不包含cash余额字段"] = function(world)
      for _, player in ipairs(_game(world).players or {}) do
        if rawget(player, "cash") ~= nil then
          return nil, "runtime player has cash field"
        end
      end
      return true
    end,

    ["acceptance状态输出不包含cash余额字段"] = function(world)
      local output = { players = {} }
      for index, player in ipairs(_game(world).players or {}) do
        output.players[index] = {
          id = player.id,
          coins = _game(world):player_balance(player, "金币"),
        }
      end
      for _, player_state in ipairs(output.players) do
        if player_state.cash ~= nil then
          return nil, "acceptance output includes cash"
        end
      end
      world.acceptance_state_output = output
      return true
    end,

    ["执行角色属性金币静态护栏"] = function(world)
      local root = _project_root()
      local ok, err = _guard_src(root)
      if not ok then
        world.role_coin_guard_error = err
        return true
      end
      ok, err = _guard_tests(root, "spec")
      if not ok then
        world.role_coin_guard_error = err
        return true
      end
      ok, err = _guard_tests(root, "tools/acceptance")
      if not ok then
        world.role_coin_guard_error = err
        return true
      end
      world.role_coin_guard_error = nil
      return true
    end,

    ["src目录不直接读写player.cash或cash余额字段"] = function(world)
      if world.role_coin_guard_error ~= nil then
        return nil, world.role_coin_guard_error
      end
      return true
    end,

    ["spec目录不构造或断言运行时player.cash余额字段"] = function(world)
      if world.role_coin_guard_error ~= nil then
        return nil, world.role_coin_guard_error
      end
      return true
    end,

    ["tools/acceptance目录不构造或断言运行时player.cash余额字段"] = function(world)
      if world.role_coin_guard_error ~= nil then
        return nil, world.role_coin_guard_error
      end
      return true
    end,

    ["旧profile输入兼容与cash_receive表现命名作为受控例外保留"] = function()
      return true
    end,
  }
end

return role_attribute_coins_steps
