local tokenizer = require("scrap4lua.tokenizer")

local query = {}

local function _collection_weight(config, collection_name)
  local weights = config.scoring.collection_weights or {}
  return weights[collection_name] or 1
end

local function _build_theme_map(themes)
  local theme_map = {}
  for _, theme in ipairs(themes or {}) do
    local bucket = theme_map[theme.center] or {}
    for _, related in ipairs(theme.related_terms or {}) do
      bucket[#bucket + 1] = related
    end
    theme_map[theme.center] = bucket
  end
  return theme_map
end

local function _contains_term(terms, target)
  for _, term in ipairs(terms or {}) do
    if term == target then
      return true
    end
  end
  return false
end

local function _push_unique(array, seen, value)
  if value ~= nil and seen[value] ~= true then
    array[#array + 1] = value
    seen[value] = true
  end
end

local function _expand_terms(raw_terms, index, query_text)
  local expanded = {}
  local seen = {}
  local theme_map = _build_theme_map(index.themes)
  local full_query = tostring(query_text or ""):lower()

  for _, term in ipairs(raw_terms or {}) do
    _push_unique(expanded, seen, term)
    for _, alias in ipairs(index.aliases and index.aliases[term] or {}) do
      _push_unique(expanded, seen, alias)
    end
    for _, related in ipairs(theme_map[term] or {}) do
      _push_unique(expanded, seen, related)
    end
  end

  for _, alias in ipairs(index.aliases and index.aliases[full_query] or {}) do
    _push_unique(expanded, seen, alias)
  end

  return expanded
end

function query.find(index, config, query_text, opts)
  local limit = (opts and opts.limit) or 10
  local raw_terms = tokenizer.tokenize(query_text, {
    stop_words = config.glossary.stop_words,
  })
  local expanded_terms = _expand_terms(raw_terms, index, query_text)
  local matches = {}

  for _, scrap in ipairs(index.scraps or {}) do
    local score = 0
    local reasons = {}
    for _, term in ipairs(raw_terms) do
      if _contains_term(scrap.terms, term) then
        score = score + 8
        reasons[#reasons + 1] = "direct:" .. term
      end
    end
    for _, term in ipairs(expanded_terms) do
      if _contains_term(scrap.terms, term) then
        if _contains_term(raw_terms, term) ~= true then
          score = score + 3
          reasons[#reasons + 1] = "expanded:" .. term
        end
      end
    end
    if score > 0 then
      score = score * _collection_weight(config, scrap.collection)
      matches[#matches + 1] = {
        scrap_id = scrap.id,
        path = scrap.path,
        title = scrap.title,
        level = scrap.level,
        collection = scrap.collection,
        score = score,
        reasons = reasons,
      }
    end
  end

  table.sort(matches, function(left, right)
    if left.score == right.score then
      if left.path == right.path then
        return tostring(left.title) < tostring(right.title)
      end
      return left.path < right.path
    end
    return left.score > right.score
  end)

  local trimmed = {}
  for index_value = 1, math.min(limit, #matches) do
    trimmed[#trimmed + 1] = matches[index_value]
  end

  return {
    query = query_text,
    expanded_terms = expanded_terms,
    matches = trimmed,
    explanations = {
      direct_terms = raw_terms,
      alias_terms = expanded_terms,
    },
  }
end

return query
