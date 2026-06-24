local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local roster = require("src.app.roster")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local inventory = require("src.rules.items.inventory")
local constants = require("src.config.content.constants")
local balance = require("src.player.actions.balance")

local setup_steps = {}

-- These scenarios exercise the REAL startup path (ADR 0017 D4, decision B): the
-- player-count / AI-fill rules live in src/app/roster.lua, which always builds to a
-- fixed four slots — real host roles capped at four, the remainder filled with
-- synthetic AI, no rejection. We drive roster.build_game_factory with N mocked host
-- roles and read the real assembled game; starting-state assertions read the real
-- player objects and src/config/content/constants.lua (single source — never
-- hardcoded 100000 / 5).

local function _mock_roles(count)
  local roles = {}
  for i = 1, count do
    local role_id = 100 + i
    local attrs = {}
    roles[i] = {
      get_roleid = function() return role_id end,
      get_name = function() return "真人" .. tostring(i) end,
      get_attr_raw_fixed = function(_, attr_id) return attrs[attr_id] end,
      set_attr_raw_fixed = function(_, attr_id, value)
        attrs[attr_id] = value
        return attr_id == balance.COIN_COUNT_ATTR_ID
      end,
    }
  end
  return roles
end

-- runtime_ports.resolve_roles + GameAPI.random_int are roster's only host couplings.
-- Both are stubbed for the synchronous build and restored to the clean (unconfigured)
-- acceptance baseline immediately after, so sibling scenarios are unaffected.
local function _build_via_roster(world, signup_count)
  local saved_gameapi = _G.GameAPI
  _G.GameAPI = { random_int = function(min, _) return min end }
  runtime_ports.configure({
    resolve_roles = function() return _mock_roles(signup_count) end,
  })
  local ok, result = pcall(function()
    return roster.build_game_factory({}, { build_mode = "release" })()
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

function setup_steps.handlers()
  return {
    ["游戏配置为标准大富翁模式"] = function(world)
      world.setup_game = nil
      return true
    end,

    -- ── 场景大纲: 报名真人不足时补足电脑角色到4人 / 截断 ──────────────────────
    ["本局报名真人玩家数为<报名人数>"] = function(world, example)
      local count = number_utils.to_integer(example["报名人数"])
      if count == nil then
        return nil, "invalid 报名人数: " .. tostring(example["报名人数"])
      end
      world.signup_count = count
      return true
    end,

    ["本局报名真人玩家数为5"] = function(world)
      world.signup_count = 5
      return true
    end,

    ["游戏初始化"] = function(world)
      _build_via_roster(world, world.signup_count or 0)
      return true
    end,

    ["本局行动角色数为4"] = function(world)
      local actual = #world.setup_game.players
      if actual ~= 4 then
        return nil, "expected 4 action roles, got " .. tostring(actual)
      end
      return true
    end,

    ["其中电脑角色数为<电脑数>"] = function(world, example)
      local expected = number_utils.to_integer(example["电脑数"])
      if expected == nil then
        return nil, "invalid 电脑数: " .. tostring(example["电脑数"])
      end
      local actual = _count_ai_players(world.setup_game)
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. " AI roles, got " .. tostring(actual)
      end
      return true
    end,

    ["游戏允许开始"] = function(world)
      if world.setup_game == nil then
        return nil, "no game was initialized"
      end
      if #world.setup_game.players ~= 4 then
        return nil, "a startable game must seat 4 action roles, got " .. tostring(#world.setup_game.players)
      end
      return true
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
        if player.position ~= start_idx then
          return "player " .. tostring(index) .. " should start at tile " .. tostring(start_idx) ..
            ", got " .. tostring(player.position)
        end
      end)
    end,

    ["每名角色初始金币为100000"] = function(world)
      return _each_player(world, function(player, index)
        local cash = world.setup_game:player_balance(player, "金币")
        if cash ~= constants.starting_cash then
          return "player " .. tostring(index) .. " should start with " .. tostring(constants.starting_cash) ..
            " coins, got " .. tostring(cash)
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
        local items = inventory.count(player)
        if items ~= 0 then
          return "player " .. tostring(index) .. " should hold 0 items, got " .. tostring(items)
        end
      end)
    end,

    ["每名角色道具卡槽上限为5"] = function(world)
      return _each_player(world, function(player, index)
        local cap = player.inventory.max_slots
        if cap ~= constants.inventory_slots then
          return "player " .. tostring(index) .. " slot cap should be " .. tostring(constants.inventory_slots) ..
            ", got " .. tostring(cap)
        end
      end)
    end,
  }
end

return setup_steps
