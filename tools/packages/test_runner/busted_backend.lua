--- Real busted execution; project events bracket the complete hook chain.
local M = {}
function M.run(files, helper, output, arguments)
  local busted = require("busted.core")()
  local real_it
  local register = busted.register
  busted.register = function(descriptor, executor, attributes)
    if descriptor == "it" and type(executor) == "function" then real_it = executor end
    return register(descriptor, executor, attributes)
  end
  require("busted")(busted)
  busted.register = register
  -- Preserve ordinary require identity across files. Specs own singleton patches.
  busted.register("file", "file", {})
  local events = require("packages.test_runner.events")
  local counts = { files = #files, cases = 0, passed = 0, failed = 0, errors = 0 }
  local pending, current
  local file_cases = {}
  local function element(test)
    local names = { test.name }
    local parent = busted.context.parent(test)
    while parent and parent.descriptor ~= "file" do
      if parent.name then table.insert(names, 1, parent.name) end
      parent = busted.context.parent(parent)
    end
    return { name = test.name, full_name = table.concat(names, " "), trace = test.trace }
  end
  local function finish()
    if not pending then return end
    counts.cases = counts.cases + 1
    events.publish({ "test", "end" }, pending.element, nil, pending.status, pending.message)
    pending, current = nil, nil
  end
  busted.subscribe({ "error" }, function(test, _, message)
    if current then current.message = message; current.error = true
    else counts.errors = counts.errors + 1 end
    io.write("not ok - busted hook/load error: " .. tostring(test.name) .. "\n# " .. tostring(message):gsub("\n", "\n# ") .. "\n")
    return nil, true
  end)
  busted.subscribe({ "failure" }, function(test, _, message)
    if current then current.message = message end
    if test.descriptor ~= "it" then
      if current then current.error = true else counts.errors = counts.errors + 1 end
    end
    return nil, true
  end)
  busted.subscribe({ "test", "end" }, function(test, _, status)
    pending = { element = element(test), status = status, message = current and current.message }
    return nil, true
  end)
  if output == "TAP" then require("packages.test_runner.tap_handler").tap_handler_factory({ arguments = arguments })
  else assert(loadfile(output))()({ arguments = arguments }) end
  if helper then assert(loadfile(helper))() end
  -- Wrap the genuine it executor at busted's public register seam. Its normal
  -- nested hook traversal is unchanged; project events bracket the whole call.
  busted.register("it", function(test)
    current = {}
    local project_element = element(test)
    project_element.trace = project_element.trace or {}
    local file = busted.getFile(test)
    if file then
      project_element.trace.source = "@" .. file.name
      file_cases[file.name] = (file_cases[file.name] or 0) + 1
    end
    events.publish({ "test", "start" }, project_element, nil)
    local status = busted.safe("it", function() real_it(test) end, test)
    if not pending then
      pending = { element = project_element, status = "error", message = "test hook failed before body" }
    end
    if not status:success() or current.error then pending.status = "error"; pending.message = current.message end
    finish()
  end)
  require("busted.modules.test_file_loader")(busted, { "lua" })(files, {}, { excludes = {}, recursive = false })
  require("busted.execute")(busted)(1, {})
  finish()
  for _, file in ipairs(files) do
    if not file_cases[file] then
      counts.errors = counts.errors + 1
      io.write("not ok - empty spec file: " .. file .. "\n")
    end
  end
  events.publish({ "suite", "end" })
  counts.passed = events.results.successes
  counts.failed = events.results.failures
  counts.errors = counts.errors + events.results.errors
  return counts
end
return M
