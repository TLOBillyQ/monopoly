package.path = package.path .. ";./tests/?.lua"

local guard_support = require("internal.guard_support")

local retired_exact_paths = {
  "src.core.runtime_facade",
  "src.game.turn_engine",
  "src.game.legacy.turn_engine",
  "src.presentation.adapter",
  "src.presentation.canvas_runtime",
  "src.game.systems.market.service",
  "src.app.bootstrap.runtime_install",
  "src.core.ports.turn_ui_sync_shared",
  "src.core.choice.choice_contract",
  "src.core.choice.choice_route_policy",
  "src.presentation.runtime.host_runtime",
  "src.presentation.runtime.ui_view_service",
  "src.presentation.model.model",
  "src.presentation.runtime.view_service",
  "src.presentation.runtime.presentation_ports",
  "src.presentation.runtime.runtime",
  "src.presentation.view.render.board_runtime",
  "src.presentation.view.render.status_3_d_service",
  "src.presentation.view.render.status3d_service",
  "src.game.flow.turn.runtime",
  "src.infrastructure.runtime.runtime_context",
  "src.infrastructure.runtime.runtime_event_bridge",
  "src.game.systems.board.board",
  "src.game.systems.movement.movement",
  "src.game.core.player.player",
  "src.game.scheduler.scheduler",
  "src.game.systems.market.market_service",
  "src.game.systems.vehicle.vehicle_feature",
}

local retired_prefixes = {
  "src.game.systems.choices.choice_",
  "src.presentation.runtime.presentation_ports.",
  "src.presentation.view.widgets.ui_",
  "src.presentation.input.ui_",
  "src.game.core.runtime.game_state_",
  "src.game.flow.turn.gameplay_loop",
  "src.game.flow.turn.turn_",
  "src.game.systems.land.land_",
  "src.presentation.view.render.market_view",
  "src.presentation.view.render.action_anim_",
  "src.presentation.runtime.ui_",
  "src.presentation.model.ui_",
  "src.game.systems.land.landing_",
  "src.game.systems.items.item_",
}

local scan_roots = { "src", "tests" }

local function _should_skip(_, relpath)
  return relpath:match("^vendor/") ~= nil
    or relpath:match("^Config/") ~= nil
    or relpath:match("^Data/") ~= nil
    or relpath:match("^tests/internal/legacy_path_guard%.lua$") ~= nil
end

local M = {}

function M.run(opts)
  opts = opts or {}
  local exact_paths = opts.retired_exact_paths or retired_exact_paths
  local prefixes = opts.retired_prefixes or retired_prefixes
  local violations, err = guard_support.collect_line_violations({
    roots = opts.scan_roots or scan_roots,
    skip_path = opts.skip_path or _should_skip,
    find_violation = function(_, relpath, line, line_number)
      if guard_support.is_comment_line(line) then
        return nil
      end

      local retired_token = nil
      for _, retired_path in ipairs(exact_paths) do
        if line:find(retired_path, 1, true) then
          retired_token = retired_path
          break
        end
      end
      if retired_token == nil then
        for _, retired_prefix in ipairs(prefixes) do
          if line:find(retired_prefix, 1, true) then
            retired_token = retired_prefix
            break
          end
        end
      end
      if retired_token == nil then
        return nil
      end

      return {
        path = relpath,
        line = line_number,
        retired_path = retired_token,
        text = line,
      }
    end,
  })

  if err then
    return { ok = false, error = err }
  end

  if #violations > 0 then
    return { ok = false, violations = violations }
  end

  return { ok = true }
end

local function _main()
  local result = M.run()
  if result.error then
    io.stderr:write("legacy_path_guard error: ", result.error, "\n")
    os.exit(1)
  end
  if result.violations then
    io.stderr:write("legacy_path_guard found retired module paths:\n")
    for _, violation in ipairs(result.violations) do
      io.stderr:write(
        "legacy_path_guard: ",
        violation.path,
        ":",
        tostring(violation.line),
        " contains ",
        violation.retired_path,
        "\n"
      )
      io.stderr:write("  ", violation.text, "\n")
    end
    os.exit(1)
  end

  print("legacy_path_guard ok")
end

if ... == nil then
  _main()
else
  return M
end
