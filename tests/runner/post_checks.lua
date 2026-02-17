local post_checks = {}

function post_checks.resolve_include_internal(opts)
  if opts and opts.include_internal ~= nil then
    return opts.include_internal == true
  end
  return true
end

return post_checks
