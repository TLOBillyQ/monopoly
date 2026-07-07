local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local land_actions = require("src.rules.land.actions")
local chance_resolver = require("src.rules.chance.resolver")

local bankruptcy_steps = {}

-- The bankruptcy scenarios drive the REAL settlement chains over game_driver's
-- shared ctx (ADR 0017 D1.2): rent -> land_actions.execute_pay_rent ->
-- land_events.apply -> bankruptcy_port.eliminate; chance -> chance_resolver.resolve
-- -> handlers.pay_others / collect_from_others -> handle_bankruptcy_if_non_positive;
-- hospital -> game:player_apply_hospital_effects. Every "破产/淘汰" assertion reads
-- the real player.eliminated flag, never a fixture-local bankrupt boolean.

local _RENT_TILE_ID = 1 -- 福州路, a standard land tile we re-price for a deterministic rent

local function _ctx(world) return world.driver end
local function _game(world) return world.driver.game end
local function _player(world) return game_driver.current_player(world.driver) end

local function _opponents(world)
  local game = _game(world)
  local me = _player(world)
  local list = {}
  for _, p in ipairs(game.players) do
    if p.id ~= me.id then
      list[#list + 1] = p
    end
  end
  return list
end

local function _balance(world, player)
  return _game(world):player_cash(player)
end

function bankruptcy_steps.handlers()
  return {
    -- ── shared verification-column handlers (used by economy.feature and
    -- chance.feature; bankruptcy.feature no longer references them but they
    -- must remain registered for those features) ─────────────────────────────
    ["玩家初始余额为<验证余额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证余额"])
      if expected == nil then
        return nil, "invalid 验证余额: " .. tostring(example["验证余额"])
      end
      if not (world.player and world.player.cash == expected) then
        return nil, "expected initial cash=" .. tostring(expected) ..
          ", got " .. tostring(world.player and world.player.cash)
      end
      return true
    end,

    ["应支付金额为<验证金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证金额"])
      if expected == nil then
        return nil, "invalid 验证金额: " .. tostring(example["验证金额"])
      end
      if world.payment_attempted ~= expected then
        return nil, "expected payment_attempted=" .. tostring(expected) ..
          ", got " .. tostring(world.payment_attempted)
      end
      return true
    end,

    -- ── 场景大纲: 落在对手地块结算租金后的破产判定 ─────────────────────────────
    ["结算租金前玩家持有<余额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["余额"])
      if amount == nil then
        return nil, "invalid 余额: " .. tostring(example["余额"])
      end
      _game(world):set_player_cash(_player(world), amount)
      world.bk_balance = amount
      return true
    end,

    ["对手拥有玩家所在地块且应付租金为<租金>金币"] = function(world, example)
      local rent = number_utils.to_integer(example["租金"])
      if rent == nil then
        return nil, "invalid 租金: " .. tostring(example["租金"])
      end
      local game = _game(world)
      local opponent = _opponents(world)[1]
      local tile = game.board:get_tile_by_id(_RENT_TILE_ID)
      -- rent_for_level at level 0 = floor(price * 0.5); set price so a single
      -- opponent-owned tile yields exactly the requested rent.
      tile.price = rent * 2
      tile.level = 0
      game:set_tile_owner(tile, opponent.id)
      local idx = game.board:index_of_tile_id(_RENT_TILE_ID)
      game_driver.set_player_position(_ctx(world), _player(world), idx)
      world.bk_rent = rent
      return true
    end,

    ["玩家落地结算租金"] = function(world)
      land_actions.execute_pay_rent(_game(world), _player(world).id, _RENT_TILE_ID)
      return true
    end,

    ["结算后玩家<结果>"] = function(world, example)
      local result = example["结果"]
      local player = _player(world)
      if result == "破产" then
        if not player.eliminated then
          return nil, "player should be eliminated after rent settlement"
        end
      elseif result == "存活" then
        if player.eliminated then
          return nil, "player should survive rent settlement"
        end
        local expected_cash = (world.bk_balance or 0) - (world.bk_rent or 0)
        if _balance(world, player) ~= expected_cash then
          return nil, "expected surviving cash=" .. tostring(expected_cash) ..
            ", got " .. tostring(_balance(world, player))
        end
      else
        return nil, "unknown 结果: " .. tostring(result)
      end
      return true
    end,

    -- ── 场景: 机会卡向每位对手支付效果中途破产停止后续支付 ─────────────────────
    ["支付机会卡前玩家持有1000金币"] = function(world)
      _game(world):set_player_cash(_player(world), 1000)
      return true
    end,

    ["游戏中有3名未淘汰对手"] = function(world)
      local opponents = _opponents(world)
      local active = 0
      for _, opp in ipairs(opponents) do
        if not opp.eliminated then active = active + 1 end
      end
      if active ~= 3 then
        return nil, "expected 3 active opponents, got " .. tostring(active)
      end
      return true
    end,

    ["玩家结算向每位对手支付500金币的机会卡"] = function(world)
      local opponents = _opponents(world)
      world.bk_opp_before = {}
      for i, opp in ipairs(opponents) do
        world.bk_opp_before[i] = _balance(world, opp)
      end
      chance_resolver.resolve(_game(world), _player(world), {
        effect = "pay_others",
        amount = 500,
      })
      return true
    end,

    ["玩家支付前两位对手各500金币后破产淘汰"] = function(world)
      if not _player(world).eliminated then
        return nil, "player should be eliminated mid-payment"
      end
      local opponents = _opponents(world)
      for i = 1, 2 do
        local gained = _balance(world, opponents[i]) - world.bk_opp_before[i]
        if gained ~= 500 then
          return nil, "opponent " .. tostring(i) .. " should have received 500, gained " .. tostring(gained)
        end
      end
      return true
    end,

    ["第三位对手不再收到支付"] = function(world)
      local opponents = _opponents(world)
      local gained = _balance(world, opponents[3]) - world.bk_opp_before[3]
      if gained ~= 0 then
        return nil, "third opponent should receive nothing, gained " .. tostring(gained)
      end
      return true
    end,

    -- ── 场景: 机会卡向每位对手收取效果中无力支付的对手破产淘汰 ─────────────────
    ["对手A持有500金币"] = function(world)
      local opponent_a = _opponents(world)[1]
      _game(world):set_player_cash(opponent_a, 500)
      world.bk_opponent_a = opponent_a
      return true
    end,

    ["玩家结算向每位对手收取1000金币的机会卡"] = function(world)
      world.bk_player_before = _balance(world, _player(world))
      chance_resolver.resolve(_game(world), _player(world), {
        effect = "collect_from_others",
        amount = 1000,
      })
      return true
    end,

    ["对手A支付全部500金币后破产淘汰"] = function(world)
      local opponent_a = world.bk_opponent_a
      if not opponent_a.eliminated then
        return nil, "opponent A should be eliminated after being unable to pay"
      end
      return true
    end,

    ["玩家至少收到对手A的500金币"] = function(world)
      local gained = _balance(world, _player(world)) - (world.bk_player_before or 0)
      if gained < 500 then
        return nil, "player should collect at least 500 from opponent A, gained " .. tostring(gained)
      end
      return true
    end,

    -- ── 场景: 落在医院支付住院费不足时破产淘汰 ────────────────────────────────
    ["落院前玩家持有0金币"] = function(world)
      _game(world):set_player_cash(_player(world), 0)
      return true
    end,

    ["玩家落在医院结算住院费"] = function(world)
      _game(world):player_apply_hospital_effects(_player(world))
      return true
    end,

    ["玩家因住院费破产淘汰"] = function(world)
      if not _player(world).eliminated then
        return nil, "player should be eliminated after an unpayable hospital fee"
      end
      return true
    end,
  }
end

return bankruptcy_steps
