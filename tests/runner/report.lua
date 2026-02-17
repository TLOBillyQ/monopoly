local report = {}

local function _safe_tostring(value)
  if value == nil then
    return "nil"
  end
  return tostring(value)
end

function report.on_case_ok()
  io.stdout:write(".")
end

function report.on_case_failed()
  io.stdout:write("F")
end

function report.finish(total, failures)
  if #failures > 0 then
    io.stdout:write("\n")
    print("Regression failed (" .. tostring(#failures) .. "/" .. tostring(total) .. ")")
    for index, failure in ipairs(failures) do
      print(tostring(index) .. ") [" .. _safe_tostring(failure.layer) .. "/" .. _safe_tostring(failure.domain) .. "] " .. _safe_tostring(failure.id))
      print(_safe_tostring(failure.err))
    end
    error("regression failed")
  end

  print("\nAll regression checks passed (" .. tostring(total) .. ")")
end

return report
