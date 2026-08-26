-- 初始游戏对象构造助手(自 compose_game.lua 拆分,行为保持):玩家索引、
-- 地块初始态、市场限额、初始 turn 与默认字段装配。组合根保留装载时序,
-- 这里只承载纯构造逻辑。
local market_cfg = require("src.config.content.market")
local game_factory = require("src.app.game_factory")
local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local dirty_tracker = require("src.state.dirty_tracker")

local game_defaults = {}

-- 归一化 player 的 role id 后按 id 收录,id 非法(空/无法归一化)时跳过。
local function _insert_normalized_player(out, p)
  if p and p.id ~= nil then
    local player_id = role_id_utils.normalize(p.id)
    if player_id ~= nil then
      out[player_id] = p
    end
  end
end

function game_defaults.build_player_by_id(players)
  local out = {}
  for _, p in ipairs(players or {}) do
    _insert_normalized_player(out, p)
  end
  return out
end

function game_defaults.init_tile_state(board)
  for _, t in ipairs(board.path) do
    if t.type == "land" then
      t.owner_id = nil
      t.level = 0
    end
  end
end

function game_defaults.build_market_limits()
  local limits = {}
  for _, entry in ipairs(market_cfg) do
    local limit = number_utils.to_integer(entry.limit)
    if limit and limit >= 1 then
      limits[entry.product_id] = limit
    end
  end
  return limits
end

function game_defaults.build_initial_turn()
  return {
    current_player_index = 1,
    turn_count = 0,
    countdown_seconds = 0,
    countdown_active = false,
    phase = "start",
    pending_choice = nil,
    choice_seq = 0,
    move_anim_seq = 0,
    move_anim = nil,
    action_anim_seq = 0,
    action_anim = nil,
    action_anim_queue = {},
    landing_visual_hold_active = false,
    landing_visual_release_pending = false,
    move_followup_pending = false,
    detained_wait_active = false,
    detained_wait_seconds = 0,
    detained_wait_elapsed = 0,
    inter_turn_wait_active = false,
    inter_turn_wait_seconds = 0,
    inter_turn_wait_elapsed = 0,
    no_action_notice_active = false,
    no_action_notice_player_id = nil,
    no_action_notice_text = nil,
    item_phase = {},
    used_effect_groups = {},
    item_phase_active = "",
    market_prompt = nil,
    post_action = nil,
  }
end

function game_defaults.is_class_like(value)
  if type(value) ~= "table" then
    return false
  end
  local meta = getmetatable(value)
  local is_instance = type(meta) == "table" and type(meta.__newindex) == "function"
  if is_instance then
    return false
  end
  return value.__name ~= nil and type(value.new) == "function"
end

function game_defaults.apply_game_defaults(game, opts, board, players, dirty)
  game.board = board
  game.players = players
  game.player_by_id = game_defaults.build_player_by_id(players)
  game.turn = game_defaults.build_initial_turn()
  game.turn.turn_start_prompt_seq = 0
  game.turn.turn_start_prompt_player_id = nil
  game.dirty = dirty
  game.market_limits = game_defaults.build_market_limits()
  game.rng = opts.rng or game_factory.build_rng()
  game.finished = false
  game.winner = nil
  game.last_turn = nil
  game._land_rent_version = 0
  game._land_rent_cache = nil
  game.tile_owner_notifier = game.tile_owner_notifier or {
    notify_owner_changed = function() end,
  }
  game.board_visual_feedback_port = game.board_visual_feedback_port or {
    sync_many = function()
      return false
    end,
  }
  game.intent_output_port = game.intent_output_port or intent_dispatcher.build_port()
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
end

return game_defaults

--[[ mutate4lua-manifest
version=4
projectHash=91c7b4bcda6fe680
scope.0.id=chunk:src/app/game_defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=127
scope.0.semanticHash=5cf2ce476f535e7b
scope.1.id=function:_insert_normalized_player
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=21
scope.1.semanticHash=51c3a5d70d994210
scope.2.id=function:game_defaults.build_player_by_id
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=8cea00c493eb20e7
scope.3.id=function:game_defaults.init_tile_state
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=38
scope.3.semanticHash=ce68ee4efb56113b
scope.4.id=function:game_defaults.build_market_limits
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=49
scope.4.semanticHash=04a25af57068b1fe
scope.5.id=function:game_defaults.build_initial_turn
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=83
scope.5.semanticHash=c7626f0cb8d70c1b
scope.6.id=function:game_defaults.is_class_like
scope.6.kind=function
scope.6.startLine=85
scope.6.endLine=95
scope.6.semanticHash=596638be3fddc0a5
scope.7.id=function:game_defaults.apply_game_defaults
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=124
scope.7.semanticHash=b161d0ec508894a5
scope.8.id=function:<anonymous>
scope.8.kind=function
scope.8.startLine=113
scope.8.endLine=113
scope.8.semanticHash=f5774b2783966d88
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=116
scope.9.endLine=118
scope.9.semanticHash=22b57f529f3a8828
scope.10.id=function:game:consume_dirty
scope.10.kind=function
scope.10.startLine=121
scope.10.endLine=123
scope.10.semanticHash=bfe12c21851ff26e
]]
