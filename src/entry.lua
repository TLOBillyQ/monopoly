local Entry = {}

local function parse_args(args)
  local platform = nil
  local all_ai = false
  for _, v in ipairs(args or {}) do
    if v == "--all-ai" then
      all_ai = true
    else
      local found = v:match("^%-%-platform=(.+)$")
      if found then
        platform = found
      end
    end
  end
  return platform, all_ai
end

local function resolve_platform(opts)
  opts = opts or {}
  local arg_platform, arg_all_ai = parse_args(arg)
  local platform = opts.platform or os.getenv("MONOPOLY_PLATFORM") or arg_platform
  if platform == "all-ai" then
    platform = "headless"
  end
  if not platform then
    if arg_all_ai then
      platform = "headless"
    elseif rawget(_G, "LuaAPI") and rawget(_G, "EVENT") then
      platform = "eggy"
    else
      platform = "headless"
    end
  end
  return platform, arg_all_ai
end

local function create_game(all_ai_mode)
  local Game = require("src.game")
  if all_ai_mode then
    return Game.new({
      players = { "AI1", "AI2", "AI3", "AI4" },
      ai = { [1] = true, [2] = true, [3] = true, [4] = true },
      auto_all = true,
    })
  end
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
  })
end

function Entry.run(opts)
  opts = opts or {}
  local platform = resolve_platform(opts)
  local all_ai_mode = platform == "headless"
  local game_factory = opts.game_factory or function()
    return create_game(all_ai_mode)
  end

  if platform == "headless" then
    print("=== All-AI Mode Start ===")

    local logger = require("src.util.logger")
    logger.clear()

    local game = game_factory()
    print("Players: " .. #game.players .. " AI players")
    logger.info("All-AI Mode Start, player count:", #game.players)

    local steps = 0
    local max_steps = 10000
    local prev_alive = #game:alive_players()
    while not game.finished and steps < max_steps do
      game:advance_turn()
      steps = steps + 1

      local alive = game:alive_players()
      if #alive < prev_alive then
        local turn_count = game.store and game.store:get({ "turn", "turn_count" }) or 0
        print("Turn: " .. turn_count .. ", Alive: " .. #alive .. " (Steps: " .. steps .. ")")
        prev_alive = #alive
      end
    end

    print("\n=== Game Over ===")
    local final_turn = game.store and game.store:get({ "turn", "turn_count" }) or 0
    print("Turn count: " .. final_turn)
    print("Steps executed: " .. steps)
    if game.winner_names then
      print("Winner: " .. game.winner_names)
    else
      print("No winner")
    end

    print("\nPlayer status:")
    for _, p in ipairs(game.players) do
      local status = p.eliminated and "Eliminated" or "Alive"
      print("  " .. p.name .. ": " .. status .. ", Cash: " .. (p.cash or 0))
    end
    return nil
  end

  if platform == "eggy" then
    local EggyRuntime = require("src.adapters.eggy.eggy_runtime")
    return EggyRuntime.install()
  end

  error("Unknown platform: " .. tostring(platform))
end

return Entry
