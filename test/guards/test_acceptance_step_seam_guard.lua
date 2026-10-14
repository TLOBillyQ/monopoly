require("test.bootstrap").install_package_paths()

local luassert = assert
local guard = require("test.guards.lib.acceptance_step_seam_guard")

-- ADR 0017 接缝白名单(#165):tools/packages/acceptance/steps/** 不得 require
-- src.rules 内部模块(ports 除外)。喂合成违规输入,断言 guard 真的会红。

local function _reader(files)
  return function(path)
    return files[path]
  end
end

local function _check(files, exemptions)
  local paths = {}
  for path in pairs(files) do
    paths[#paths + 1] = path
  end
  table.sort(paths)
  return guard.check(paths, _reader(files), exemptions or {})
end

describe("TestAcceptanceStepSeamGuard", function()
  it("test_放行 foundation/config/ui/ports/driver/context 的 require", function()
    local violations = _check({
      ["tools/packages/acceptance/steps/ok.lua"] = [[
local number_utils = require("src.foundation.number")
local items_cfg = require("src.config.content.items")
local runtime_state = require("src.ui.state.runtime")
local intent_output = require("src.rules.ports.intent_output")
local game_driver = require("packages.acceptance.game_driver")
local mutator_status = require("packages.acceptance.steps.mutator_status")
]],
    })
    luassert.is.equal(0, #violations)
  end)

  it("test_对 src.rules 内部 require 变红,报模块 + 越界列表 + 指引", function()
    local violations = _check({
      ["tools/packages/acceptance/steps/bad.lua"] = [[
local inventory = require("src.rules.items.inventory")
local query = require("src.rules.board.query")
]],
    })
    luassert.is.equal(1, #violations)
    local text = violations[1]
    luassert.truthy(text:find("tools/packages/acceptance/steps/bad.lua", 1, true))
    luassert.truthy(text:find("src.rules.items.inventory", 1, true))
    luassert.truthy(text:find("src.rules.board.query", 1, true))
    luassert.truthy(text:find("driver", 1, true), "guidance should mention driver verbs")
  end)

  it("test_src.rules.ports.* 不算越界", function()
    local violations = _check({
      ["tools/packages/acceptance/steps/ports_ok.lua"] = [[
local paid = require("src.rules.ports.paid_purchase")
local feed = require("src.rules.ports.event_feed")
]],
    })
    luassert.is.equal(0, #violations)
  end)

  it("test_豁免清单里的存量模块不报,未列出的照红", function()
    local files = {
      ["tools/packages/acceptance/steps/legacy.lua"] = [[local x = require("src.rules.items.inventory")]],
      ["tools/packages/acceptance/steps/fresh.lua"] = [[local x = require("src.rules.items.inventory")]],
    }
    local violations = _check(files, { ["tools/packages/acceptance/steps/legacy.lua"] = true })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("fresh.lua", 1, true))
  end)

  it("test_豁免清单里已不越界的模块提示可摘除", function()
    local violations = _check(
      { ["tools/packages/acceptance/steps/clean.lua"] = [[local n = require("src.foundation.number")]] },
      { ["tools/packages/acceptance/steps/clean.lua"] = true }
    )
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("豁免", 1, true),
      "stale exemption should be flagged so the list only shrinks honestly")
  end)

  it("test_run() 对真实仓库全绿(存量越界都在豁免清单里)", function()
    local result = guard.run()
    luassert.is_true(result.ok, result.error or "")
  end)
end)
