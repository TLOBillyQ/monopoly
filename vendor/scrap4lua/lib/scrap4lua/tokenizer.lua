local tokenizer = {}

local default_stop_words = {
  ["local"] = true,
  ["function"] = true,
  ["return"] = true,
  ["require"] = true,
  ["then"] = true,
  ["false"] = true,
  ["true"] = true,
  ["table"] = true,
  ["string"] = true,
  ["state"] = true,
  ["value"] = true,
  ["result"] = true,
  ["common"] = true,
  ["utils"] = true,
  ["index"] = true,
  ["data"] = true,
  ["path"] = true,
  ["name"] = true,
  ["tests"] = true,
  ["test"] = true,
}

local function split_identifier(text)
  local expanded = tostring(text or "")
  expanded = expanded:gsub("([a-z0-9])([A-Z])", "%1 %2")
  expanded = expanded:gsub("[./:_%-]", " ")
  expanded = expanded:gsub("[^%w%s]", " ")
  return expanded
end

local function build_stop_words(extra)
  local stop_words = {}
  for key in pairs(default_stop_words) do
    stop_words[key] = true
  end
  for _, value in ipairs(extra or {}) do
    stop_words[tostring(value):lower()] = true
  end
  return stop_words
end

function tokenizer.tokenize(text, opts)
  local source = split_identifier(text)
  local stop_words = build_stop_words(opts and opts.stop_words)
  local terms = {}
  local seen = {}

  for raw in source:gmatch("[%w_]+") do
    local term = raw:lower()
    if #term >= 2 and stop_words[term] ~= true and term:match("^%d+$") == nil then
      if seen[term] ~= true then
        terms[#terms + 1] = term
        seen[term] = true
      end
    end
  end

  table.sort(terms)
  return terms
end

return tokenizer
