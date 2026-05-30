local runtime_ui = require("src.ui.render.runtime_ui")
local support = require("spec.support.shared_support")
local _with_patches = support.with_patches

describe("runtime_ui._traceback xpcall handler", function()
  it("invokes global traceback function when defined and uses its return as the rethrown error", function()
    local marker = "[MARK_TB]"
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = function(err) return marker .. tostring(err) end },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("role-A", function()
          error("boom_err_marker")
        end)
      end)
      assert(ok == false, "expected error to propagate from with_client_role")
      assert(type(captured) == "string", "expected captured error to be a string, got " .. type(captured))
      assert(captured:find(marker, 1, true) ~= nil,
        "expected marker '" .. marker .. "' in rethrown error: " .. tostring(captured))
      assert(captured:find("boom_err_marker", 1, true) ~= nil,
        "expected original error text in rethrown error: " .. tostring(captured))
    end)
  end)

  it("returns err verbatim when global traceback is nil (sandbox fallback arm)", function()
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = nil },
    }, function()
      local sentinel = "sentinel_NoTB_err"
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("role-B", function()
          error(sentinel)
        end)
      end)
      assert(ok == false, "expected error to propagate")
      assert(type(captured) == "string", "expected captured error to be a string")
      assert(captured:find(sentinel, 1, true) ~= nil,
        "expected raw err propagated when traceback absent: " .. tostring(captured))
    end)
  end)

  it("returns err verbatim when global traceback is a non-function value", function()
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = "not_a_function" },
    }, function()
      local sentinel = "sentinel_StringTB_err"
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("role-C", function()
          error(sentinel)
        end)
      end)
      assert(ok == false, "expected error to propagate")
      assert(captured:find(sentinel, 1, true) ~= nil,
        "expected raw err when traceback is non-function: " .. tostring(captured))
    end)
  end)

  it("restores previous client_role even when fn errors and traceback fallback is in play", function()
    _with_patches({
      { key = "UIManager", value = { client_role = "previous_role_id" } },
      { key = "traceback", value = nil },
    }, function()
      pcall(function()
        runtime_ui.with_client_role("transient_role_id", function()
          error("transient_fn_error")
        end)
      end)
      assert(UIManager.client_role == "previous_role_id",
        "expected previous_role_id restored after fn error, got " .. tostring(UIManager.client_role))
    end)
  end)
end)
