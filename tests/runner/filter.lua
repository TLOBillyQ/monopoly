local filter = {}

local function _split_csv(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local set = {}
  for token in string.gmatch(value, "[^,]+") do
    local normalized = string.gsub(token, "^%s*(.-)%s*$", "%1")
    if normalized ~= "" then
      set[normalized] = true
    end
  end
  return set
end

function filter.from_opts(opts)
  opts = opts or {}
  local spec_filter = {
    layers = opts.layers or _split_csv(os.getenv("TEST_LAYERS")),
    domains = opts.domains or _split_csv(os.getenv("TEST_DOMAINS")),
  }
  if spec_filter.layers == nil and spec_filter.domains == nil then
    return nil
  end
  return spec_filter
end

function filter.allow_spec(spec, spec_filter)
  if not spec_filter then
    return true
  end
  if spec_filter.layers and not spec_filter.layers[spec.layer or "unknown"] then
    return false
  end
  if spec_filter.domains and not spec_filter.domains[spec.domain or "unknown"] then
    return false
  end
  return true
end

return filter
