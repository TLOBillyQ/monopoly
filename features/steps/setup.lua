local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local roster = require("src.app.roster")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local constants = require("src.config.content.constants")
local balance = require("src.player.actions.balance")

-- 这些场景走真实启动路径：人数/AI 补足规则住
-- src/app/roster.lua，恒定装配四席——真人封顶四人、余位合成 AI、不拒开。
-- 用 N 个 mock host 角色驱动 roster.build_game_factory，断言读真实装配结果
-- 与 src/config/content/constants.lua（单一事实源——绝不硬编码 100000 / 5）。

local function _mock_roles(count)
  local roles = {}
  for i = 1, count do
    local role_id = 100 + i
    local attrs = {}
    local role = {}
    role.get_roleid = function() return role_id end
    role.get_name = function() return "真人" .. tostring(i) end
    role.get_attr_raw_fixed = function(first, second)
      local attr_id = first == role and second or first
      return attrs[attr_id]
    end
    role.set_attr_raw_fixed = function(first, second, third)
      local attr_id = first == role and second or first
      local value = first == role and third or second
      attrs[attr_id] = value
      return attr_id == balance.COIN_COUNT_ATTR_ID
    end
    roles[i] = role
  end
  return roles
end

-- runtime_ports.resolve_roles 与 GameAPI.random_int 是 roster 仅有的宿主耦合；
-- 同步构建期间打桩，构建完立刻还原到干净的验收基线，不影响邻座场景。
local function _build_via_roster(world, signup_count)
  local saved_gameapi = _G.GameAPI
  _G.GameAPI = { random_int = function(min, _) return min end }
  runtime_ports.configure({
    resolve_roles = function() return _mock_roles(signup_count) end,
  })
  local ok, result = pcall(function()
    return roster.build_game_factory({})()
  end)
  runtime_ports.reset_for_tests()
  _G.GameAPI = saved_gameapi
  assert(ok, "roster build failed: " .. tostring(result))
  world.setup_game = result
end

local function _count_ai_players(game)
  local count = 0
  for _, player in ipairs(game.players) do
    if player.is_ai == true then
      count = count + 1
    end
  end
  return count
end

local function _owned_tile_count(player)
  local count = 0
  for _, owned in pairs(player.properties or {}) do
    if owned then
      count = count + 1
    end
  end
  return count
end

local function _each_player(world, fn)
  for index, player in ipairs(world.setup_game.players) do
    local err = fn(player, index)
    if err then
      return nil, err
    end
  end
  return true
end

return dsl.steps({
  ["游戏配置为标准大富翁模式"] = function(world)
    world.setup_game = nil
    return true
  end,

  -- ── 场景大纲: 报名真人不足时补足电脑角色到4人 / 截断 ──────────────────────
  ["本局报名真人玩家数为<报名人数:int>"] = function(world, args)
    world.signup_count = args["报名人数"]
    return true
  end,

  ["本局报名真人玩家数为{报名人数:int}"] = function(world, args)
    world.signup_count = args["报名人数"]
    return true
  end,

  ["游戏初始化"] = function(world)
    _build_via_roster(world, world.signup_count or 0)
    return true
  end,

  ["本局行动角色数为4"] = function(world)
    return dsl.eq(#world.setup_game.players, 4, "行动角色数")
  end,

  ["其中电脑角色数为<电脑数:int>"] = function(world, args)
    return dsl.eq(_count_ai_players(world.setup_game), args["电脑数"], "电脑角色数")
  end,

  ["游戏允许开始"] = function(world)
    if world.setup_game == nil then
      return nil, "no game was initialized"
    end
    return dsl.eq(#world.setup_game.players, 4, "可开局席位数")
  end,

  -- ── 场景: 全部4个开局角色状态一致 ─────────────────────────────────────────
  ["游戏初始化为标准四人局"] = function(world)
    local ctx = game_driver.new_game()
    world.setup_ctx = ctx
    world.setup_game = ctx.game
    return true
  end,

  ["每名角色出生在起点"] = function(world)
    local board = world.setup_game.board
    local start_idx = board:index_of_tile_id(board.map.start_id)
    return _each_player(world, function(player, index)
      local ok = dsl.eq(player.position, start_idx, "角色" .. tostring(index) .. " 出生格")
      if not ok then
        return "player " .. tostring(index) .. " should start at tile " .. tostring(start_idx)
          .. ", got " .. tostring(player.position)
      end
    end)
  end,

  ["每名角色初始金币为100000"] = function(world)
    return _each_player(world, function(player, index)
      local cash = world.setup_game:player_cash(player)
      if cash ~= constants.starting_cash then
        return "player " .. tostring(index) .. " should start with " .. tostring(constants.starting_cash)
          .. " coins, got " .. tostring(cash)
      end
    end)
  end,

  ["每名角色初始地块数为0"] = function(world)
    return _each_player(world, function(player, index)
      local owned = _owned_tile_count(player)
      if owned ~= 0 then
        return "player " .. tostring(index) .. " should own 0 tiles, got " .. tostring(owned)
      end
    end)
  end,

  ["每名角色初始道具数为0"] = function(world)
    return _each_player(world, function(player, index)
      local items = #game_driver.items_of(nil, player)
      if items ~= 0 then
        return "player " .. tostring(index) .. " should hold 0 items, got " .. tostring(items)
      end
    end)
  end,

  ["每名角色道具卡槽上限为5"] = function(world)
    return _each_player(world, function(player, index)
      local cap = player.inventory.max_slots
      if cap ~= constants.inventory_slots then
        return "player " .. tostring(index) .. " slot cap should be " .. tostring(constants.inventory_slots)
          .. ", got " .. tostring(cap)
      end
    end)
  end,
}, { name = "setup" })
