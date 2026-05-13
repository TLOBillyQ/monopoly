--- Regression spec: equivalent to legacy `lua tests/regression.lua`.
--- Each lane is run in an isolated subprocess to preserve the legacy script's
--- per-lane state isolation. Behavior, contract, and guard lanes mirror the
--- exact lanes from `tests/regression.lua`.

local common = require("tools.shared.lib.common")

local function _busted()
  local override = os.getenv("BUSTED_BIN")
  if override and override ~= "" then
    return override
  end
  local candidates = {
    os.getenv("HOME") .. "/.luarocks/bin/busted",
    "/opt/homebrew/bin/busted",
    "/usr/local/bin/busted",
  }
  for _, candidate in ipairs(candidates) do
    if common.path_exists(candidate) then
      return candidate
    end
  end
  local resolved = common.run_command("command -v busted")
  if type(resolved) == "table" and resolved.ok and resolved.output then
    local trimmed = resolved.output:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      return trimmed
    end
  end
  error("busted not found: set BUSTED_BIN or install via luarocks/homebrew")
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
