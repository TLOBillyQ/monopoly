local M = {}

function M.bind(env, suite_module, opts)
  opts = opts or {}

  local suite_or_err, loaded_ok
  if opts.fallback_pending then
    loaded_ok, suite_or_err = pcall(require, suite_module)
  else
    suite_or_err = require(suite_module)
    loaded_ok = true
  end

  local label = opts.label
      or (loaded_ok and type(suite_or_err) == "table" and suite_or_err.name)
      or suite_module

  local _config_reset
  if opts.reset then
    _config_reset = require("spec.support.config_reset")
  end

  local describe = env.describe
  local it = env.it
  local before_each = env.before_each
  local pending = env.pending

  describe(label, function()
    if opts.reset then
      before_each(function() _config_reset.reset_all() end)
    end
    if not loaded_ok then
      pending("suite load failed: " .. tostring(suite_or_err))
      return
    end
    local cases = suite_or_err.tests or suite_or_err
    for _, case in ipairs(cases) do
      local skip_reason = opts.skip and opts.skip[case.name]
      if skip_reason then
        it(case.name, function() pending(skip_reason) end)
      else
        local run = opts.wrap and opts.wrap(case.run) or case.run
        it(case.name, run)
      end
    end
  end)
end

return M
