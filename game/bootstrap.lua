require "lib.third_party.Utils"
local dirty_tracker = require("core.dirty")
local logger = require("core.logger")
local market_cfg = require("cfg.Generated.Market")
local game_factory = require("game.factory")
local runtime_bootstrap = require("game.core.runtime")
local number_utils = require("core.math")

local bootstrap = {}

local deep_copy = Utils.deep_copy

local function _build_player_by_id(players)
  local out = {}
  for _, p in ipairs(players or {}) do
    if p and p.id ~= nil then
      out[p.id] = p
    end
  end
  return out
end

local function _init_tile_state(board)
  for _, t in ipairs(board.path) do
    if t.type == "land" then
      t.owner_id = nil
      t.level = 0
    end
  end
end

local function _build_market_limits()
  local limits = {}
  for _, entry in ipairs(market_cfg) do
    local limit = number_utils.to_integer(entry.limit)
    if limit and limit >= 1 then
      limits[entry.product_id] = limit
    end
  end
  return limits
end

local function _build_initial_turn()
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
    vehicle_resync_seq = 0,
    action_anim_seq = 0,
    action_anim = nil,
    action_anim_queue = {},
    detained_wait_active = false,
    detained_wait_seconds = 0,
    detained_wait_elapsed = 0,
    item_phase = {},
    item_phase_active = "",
    market_prompt = nil,
    post_action = nil,
  }
end

---组装游戏上下文，返回扁平的表结构
---@param opts table 初始化选项
---@return table 游戏上下文
function bootstrap.assemble(opts)
  assert(opts ~= nil, "missing assemble opts")

  -- 创建核心组件
  local board = game_factory.build_board(opts)
  local rng = game_factory.build_rng()
  local players = game_factory.build_players(opts)

  _init_tile_state(board)

  local dirty = dirty_tracker.new()

  -- 设置背包变更回调
  for _, p in ipairs(players) do
    local pid = p.id
    p.inventory._on_change = function()
      dirty_tracker.mark_inventory(dirty, pid)
    end
  end

  local registries = runtime_bootstrap.create_registries()
  local first_player = players and players[1] or nil
  local initial_turn = _build_initial_turn()
  initial_turn.turn_start_prompt_seq = 1
  initial_turn.turn_start_prompt_player_id = first_player and first_player.id or nil

  -- 构建游戏上下文表（扁平结构）
  local ctx = {
    board = board,
    players = players,
    player_by_id = _build_player_by_id(players),
    turn = initial_turn,
    dirty = dirty,
    market_limits = _build_market_limits(),
    registries = registries,
    effect_registry = registries.effects,
    rng = rng,
    logger = logger,
    finished = false,
    winner = nil,
    last_turn = nil,
    _land_rent_version = 0,
    _land_rent_cache = nil,
  }

  -- 地块所有者变更通知器
  ctx.tile_owner_notifier = {
    notify_owner_changed = function() end,
  }

  -- 从运行时上下文获取辅助对象
  local runtime_context = require("core.context")
  local rt_ctx = runtime_context.current()
  if rt_ctx then
    ctx._helpers = {
      vehicle = runtime_context.get_vehicle_helper(rt_ctx),
      camera = runtime_context.get_camera_helper(rt_ctx),
    }
  end

  -- 初始化 occupants
  bootstrap.rebuild_occupants(ctx)

  return ctx
end

---重建地块占用信息
---@param ctx table 游戏上下文
function bootstrap.rebuild_occupants(ctx)
  local length = ctx.board:length()
  ctx.occupants = {}
  for i = 1, length do
    ctx.occupants[i] = {}
  end
  for _, player_obj in ipairs(ctx.players) do
    if not player_obj.eliminated then
      local idx = player_obj.position
      table.insert(ctx.occupants[idx], player_obj.id)
    end
  end
end

return bootstrap
