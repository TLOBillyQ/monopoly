local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local effect_runner = require("src.rules.effects.runner")

-- A fake effect registry whose `get` is invoked with the colon seam the runner
-- uses (registry:get(id)). Executors are plain tables with optional can_apply
-- and a required apply.
local function _registry(executors)
  return {
    get = function(_, effect_id)
      return executors[effect_id]
    end,
  }
end

describe("effect_runner execution", function()
  it("returns ok with the executor result when the effect is allowed", function()
    local applied_ctx = nil
    local registry = _registry({
      gift = {
        apply = function(ctx)
          applied_ctx = ctx
          return "granted"
        end,
      },
    })
    local outcome = effect_runner.execute(
      { id = "gift" },
      { id = 1 },
      { id = 7 },
      { effect_registry = registry, extra = "carried" }
    )

    _assert_eq(outcome.ok, true, "allowed effect should report ok")
    _assert_eq(outcome.result, "granted", "executor result should be returned")
    _assert_eq(applied_ctx.player.id, 1, "ctx should carry the acting player")
    _assert_eq(applied_ctx.tile.id, 7, "ctx should carry the landed tile")
    _assert_eq(applied_ctx.extra, "carried", "ctx should copy game_ctx fields")
  end)

  it("blocks execution and skips apply when can_apply is false", function()
    local applied = false
    local registry = _registry({
      toll = {
        can_apply = function() return false end,
        apply = function()
          applied = true
          return "should-not-run"
        end,
      },
    })
    local outcome = effect_runner.execute({ id = "toll" }, { id = 1 }, { id = 7 }, { effect_registry = registry })

    _assert_eq(outcome.ok, false, "blocked effect should report not ok")
    _assert_eq(outcome.reason, "blocked", "blocked effect should report the blocked reason")
    _assert_eq(outcome.result, nil, "blocked effect should not carry a result")
    _assert_eq(applied, false, "blocked effect must not run apply")
  end)

  it("scan reports an entry per effect with ok/blocked status and label fallback", function()
    local registry = _registry({
      open = { apply = function() end },
      shut = { can_apply = function() return false end, apply = function() end },
    })
    local entries = effect_runner.scan(
      {
        { id = "open", label = "Open Gate", mandatory = true },
        { id = "shut" },
      },
      { id = 1 },
      { id = 7 },
      { effect_registry = registry }
    )

    _assert_eq(#entries, 2, "scan should yield one entry per effect def")
    _assert_eq(entries[1].id, "open", "first entry should track the first effect")
    _assert_eq(entries[1].label, "Open Gate", "explicit label should be preserved")
    _assert_eq(entries[1].mandatory, true, "mandatory flag should be carried")
    _assert_eq(entries[1].ok, true, "unblocked effect should scan ok")
    _assert_eq(entries[2].label, "shut", "missing label should fall back to the effect id")
    _assert_eq(entries[2].mandatory, false, "absent mandatory flag should default to false")
    _assert_eq(entries[2].ok, false, "blocked effect should scan not ok")
    _assert_eq(entries[2].reason, "blocked", "blocked scan entry should carry the reason")
  end)
end)

describe("effect_runner context resolution", function()
  it("resolves the registry from game.registries when game_ctx omits effect_registry", function()
    local registry = _registry({ grant = { apply = function() return "ok" end } })
    local game_ctx = { game = { registries = { effects = registry } } }
    local outcome = effect_runner.execute({ id = "grant" }, { id = 1 }, { id = 7 }, game_ctx)

    _assert_eq(outcome.ok, true, "registry should be resolved via game.registries.effects")
    _assert_eq(outcome.result, "ok", "executor from the resolved registry should run")
  end)

  it("build_game_ctx prefers an explicit phase, then the turn phase, then the default", function()
    local game = { turn = { phase = "wait_choice" }, rng = "RNG", registries = { effects = "REG" } }

    local explicit = effect_runner.build_game_ctx(game, "MR", { phase = "landing" })
    _assert_eq(explicit.phase, "landing", "explicit opts.phase should win")
    _assert_eq(explicit.move_result, "MR", "move_result should be forwarded")
    _assert_eq(explicit.rng, "RNG", "game rng should be carried")
    _assert_eq(explicit.effect_registry, "REG", "effect registry should default from game.registries")

    local from_turn = effect_runner.build_game_ctx(game, nil, {})
    _assert_eq(from_turn.phase, "wait_choice", "turn phase should be used when opts omits phase")

    -- The turn phase outranks opts.phase_default: a live turn (real callers pass
    -- phase_default = "landing" mid-turn) must keep its own phase, not be forced
    -- into the default. Pins the `turn.phase or phase_default` precedence.
    local turn_over_default = effect_runner.build_game_ctx(game, nil, { phase_default = "landing" })
    _assert_eq(turn_over_default.phase, "wait_choice", "turn phase must outrank phase_default when both are set")

    -- With no turn phase, phase_default is taken ahead of the "wait_choice" floor.
    local default_over_floor = effect_runner.build_game_ctx({ turn = {}, rng = "R3" }, nil, { phase_default = "landing" })
    _assert_eq(default_over_floor.phase, "landing", "phase_default should be used when the turn phase is absent")

    local fallback = effect_runner.build_game_ctx({ turn = {}, rng = "R2" }, nil, {})
    _assert_eq(fallback.phase, "wait_choice", "missing turn phase should fall back to wait_choice")
    _assert_eq(fallback.effect_registry, nil, "missing registries should leave effect_registry nil")
  end)
end)
