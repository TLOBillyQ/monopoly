--- Regression spec: equivalent to legacy `lua tests/regression.lua`.
--- Each lane is run in an isolated subprocess to preserve the legacy script's
--- per-lane state isolation. Behavior, contract, and guard lanes mirror the
--- exact lanes from `tests/regression.lua`.

local common = require("tools.shared.lib.common")

local function _busted()
  return os.getenv("HOME") .. "/.luarocks/bin/busted"
end

local function _run(label, command)
  local result = common.run_command(command)
  if type(result) ~= "table" or result.ok ~= true then
    local code = result and result.code or "?"
    local output = (result and result.output) or ""
    error(label .. " failed (code=" .. tostring(code) .. ")\n" .. tostring(output), 2)
  end
end

describe("regression suite", function()
  it("runs the behavior lane", function()
    _run("behavior lane", { _busted(), "--run=behavior" })
  end)

  it("runs the contract lane via sub-busted", function()
    _run("contract lane", { _busted(), "--run=contract" })
  end)

  it("runs the guard lane", function()
    _run("guard lane", { _busted(), "--run=guards" })
  end)
end)
