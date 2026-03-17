local common = require("shared.lib.common")
local tokenizer = require("scrap4lua.tokenizer")

local indexer = {}

local function _normalize_path(path)
  return common.normalize_path(path)
end

local function _read_file(path)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  return content
end

local function _repo_relative(project_root, path)
  local normalized_root = _normalize_path(project_root):gsub("/+$", "")
  local normalized_path = _normalize_path(path)
  if normalized_path:find(normalized_root .. "/", 1, true) == 1 then
    return normalized_path:sub(#normalized_root + 2)
  end
  return normalized_path
end

local function _matches_exclude(relpath, exclude)
  for _, pattern in ipairs(exclude or {}) do
    if relpath:find(pattern, 1, true) == 1 or relpath:find(pattern, 1, true) ~= nil then
      return true
    end
  end
  return false
end

local function _collect_collection_files(project_root, collection)
  local files = {}
  local seen = {}
  for _, root in ipairs(collection.roots or {}) do
    local abs_root = common.resolve_path(project_root, root)
    for _, suffix in ipairs(collection.include or {}) do
      local collected = common.collect_files(abs_root, suffix) or {}
      for _, path in ipairs(collected) do
        local relpath = _repo_relative(project_root, path)
        if _matches_exclude(relpath, collection.exclude) ~= true and seen[relpath] ~= true then
          files[#files + 1] = {
            abs_path = path,
            relpath = relpath,
          }
          seen[relpath] = true
        end
      end
    end
  end
  table.sort(files, function(left, right)
    return left.relpath < right.relpath
  end)
  return files
end

local function _extract_requires(content)
  local requires = {}
  local seen = {}
  for module_name in tostring(content or ""):gmatch('require%s*%(%s*["\']([^"\']+)["\']%s*%)') do
    if seen[module_name] ~= true then
      requires[#requires + 1] = module_name
      seen[module_name] = true
    end
  end
  table.sort(requires)
  return requires
end

local function _extract_functions(content)
  local functions_found = {}
  local seen = {}
  for name in tostring(content or ""):gmatch("local%s+function%s+([%w_]+)") do
    if seen[name] ~= true then
      functions_found[#functions_found + 1] = name
      seen[name] = true
    end
  end
  for name in tostring(content or ""):gmatch("function%s+([%w_%.:]+)") do
    if seen[name] ~= true then
      functions_found[#functions_found + 1] = name
      seen[name] = true
    end
  end
  table.sort(functions_found)
  return functions_found
end

local function _extract_headings(content)
  local headings = {}
  local line_number = 0
  for line in (tostring(content or "") .. "\n"):gmatch("(.-)\r?\n") do
    line_number = line_number + 1
    local marks, title = line:match("^(#+)%s+(.+)$")
    if marks ~= nil and title ~= nil then
      headings[#headings + 1] = {
        level = #marks,
        title = title,
        line = line_number,
      }
    end
  end
  return headings
end

local function _append_scrap(scraps, scrap)
  scrap.id = #scraps + 1
  scraps[#scraps + 1] = scrap
  return scrap
end

local function _build_base_text(collection, file_info, content, requires)
  local parts = {
    collection.name,
    collection.kind,
    file_info.relpath,
    table.concat(requires or {}, " "),
  }
  if collection.kind == "doc" then
    parts[#parts + 1] = content
  end
  return table.concat(parts, "\n")
end

local function _build_scraps(project_root, config)
  local scraps = {}
  local warnings = {}

  for _, collection in ipairs(config.collections or {}) do
    local files = _collect_collection_files(project_root, collection)
    for _, file_info in ipairs(files) do
      local content, err = _read_file(file_info.abs_path)
      if content == nil then
        warnings[#warnings + 1] = "failed to read " .. tostring(file_info.relpath) .. ": " .. tostring(err)
      else
        local requires = _extract_requires(content)
        local base_text = _build_base_text(collection, file_info, content, requires)
        local file_terms = tokenizer.tokenize(base_text, {
          stop_words = config.glossary.stop_words,
        })
        _append_scrap(scraps, {
          kind = collection.kind,
          collection = collection.name,
          path = file_info.relpath,
          title = file_info.relpath,
          level = "file",
          terms = file_terms,
          requires = requires,
        })

        if collection.extract and collection.extract.functions == true and collection.kind ~= "doc" then
          for _, name in ipairs(_extract_functions(content)) do
            local symbol_terms = tokenizer.tokenize(file_info.relpath .. " " .. name, {
              stop_words = config.glossary.stop_words,
            })
            _append_scrap(scraps, {
              kind = collection.kind,
              collection = collection.name,
              path = file_info.relpath,
              title = name,
              level = "symbol",
              terms = symbol_terms,
            })
          end
        end

        if collection.extract and collection.extract.headings == true and collection.kind == "doc" then
          for _, heading in ipairs(_extract_headings(content)) do
            local heading_terms = tokenizer.tokenize(file_info.relpath .. " " .. heading.title, {
              stop_words = config.glossary.stop_words,
            })
            _append_scrap(scraps, {
              kind = collection.kind,
              collection = collection.name,
              path = file_info.relpath,
              title = heading.title,
              level = "heading",
              heading_level = heading.level,
              line = heading.line,
              terms = heading_terms,
            })
          end
        end
      end
    end
  end

  return scraps, warnings
end

local function _build_alias_map(config)
  local alias_map = {}

  local function register_alias(key, value)
    local normalized_key = tostring(key):lower()
    local normalized_value = tostring(value):lower()
    alias_map[normalized_key] = alias_map[normalized_key] or {}
    alias_map[normalized_key][#alias_map[normalized_key] + 1] = normalized_value
  end

  for key, values in pairs(config.glossary.aliases or {}) do
    for _, value in ipairs(values or {}) do
      register_alias(key, value)

      local key_terms = tokenizer.tokenize(key, {
        stop_words = config.glossary.stop_words,
      })
      local value_terms = tokenizer.tokenize(value, {
        stop_words = config.glossary.stop_words,
      })
      for _, key_term in ipairs(key_terms) do
        for _, value_term in ipairs(value_terms) do
          register_alias(key_term, value_term)
        end
      end
    end
  end

  for _, aliases in pairs(alias_map) do
    table.sort(aliases)
  end
  return alias_map
end

local function _register_term(terms, key, scrap_id)
  local entry = terms[key]
  if entry == nil then
    entry = {
      term = key,
      scrap_count = 0,
      scraps = {},
    }
    terms[key] = entry
  end
  if entry.scraps[scrap_id] ~= true then
    entry.scraps[scrap_id] = true
    entry.scrap_count = entry.scrap_count + 1
  end
end

local function _build_term_map(scraps)
  local terms = {}
  local pair_counts = {}

  for _, scrap in ipairs(scraps) do
    for _, term in ipairs(scrap.terms or {}) do
      _register_term(terms, term, scrap.id)
    end

    local scrap_terms = scrap.terms or {}
    for left_index = 1, #scrap_terms do
      for right_index = left_index + 1, #scrap_terms do
        local left = scrap_terms[left_index]
        local right = scrap_terms[right_index]
        local key = left .. "|" .. right
        pair_counts[key] = (pair_counts[key] or 0) + 1
      end
    end
  end

  return terms, pair_counts
end

local function _sorted_term_entries(term_map)
  local entries = {}
  for _, entry in pairs(term_map) do
    local scraps = {}
    for scrap_id in pairs(entry.scraps) do
      scraps[#scraps + 1] = scrap_id
    end
    table.sort(scraps)
    entries[#entries + 1] = {
      term = entry.term,
      scrap_count = entry.scrap_count,
      scrap_ids = scraps,
    }
  end
  table.sort(entries, function(left, right)
    if left.scrap_count == right.scrap_count then
      return left.term < right.term
    end
    return left.scrap_count > right.scrap_count
  end)
  return entries
end

local function _build_themes(pair_counts, term_map)
  local pair_entries = {}
  for key, count in pairs(pair_counts) do
    if count >= 2 then
      local divider = key:find("|", 1, true)
      local left = key:sub(1, divider - 1)
      local right = key:sub(divider + 1)
      pair_entries[#pair_entries + 1] = {
        left = left,
        right = right,
        count = count,
      }
    end
  end
  table.sort(pair_entries, function(left, right)
    if left.count == right.count then
      if left.left == right.left then
        return left.right < right.right
      end
      return left.left < right.left
    end
    return left.count > right.count
  end)

  local themes = {}
  local theme_edges = {}
  local used_center = {}
  for _, pair in ipairs(pair_entries) do
    if used_center[pair.left] ~= true then
      themes[#themes + 1] = {
        id = #themes + 1,
        center = pair.left,
        related_terms = { pair.right },
        strength = pair.count,
        scrap_count = term_map[pair.left] and term_map[pair.left].scrap_count or 0,
      }
      used_center[pair.left] = true
    end
    if #themes >= 12 then
      break
    end
  end

  for _, theme in ipairs(themes) do
    for _, related in ipairs(theme.related_terms or {}) do
      theme_edges[#theme_edges + 1] = {
        kind = "term_term",
        from = theme.center,
        to = related,
        weight = theme.strength,
      }
    end
  end

  return themes, theme_edges
end

local function _build_scrap_edges(scraps)
  local edges = {}
  for _, scrap in ipairs(scraps) do
    for _, term in ipairs(scrap.terms or {}) do
      edges[#edges + 1] = {
        kind = "term_scrap",
        from = term,
        to = scrap.id,
        weight = 1,
      }
      if #edges >= 400 then
        return edges
      end
    end
  end
  return edges
end

local function _clone_map(values)
  local clone = {}
  for key, value in pairs(values or {}) do
    clone[key] = value
  end
  return clone
end

function indexer.build_index(config, opts)
  local project_root = common.resolve_path(common.current_dir(), opts and opts.project_root or config.project_root or ".")
  local scraps, warnings = _build_scraps(project_root, config)
  local alias_map = _build_alias_map(config)
  local term_map, pair_counts = _build_term_map(scraps)
  local themes, theme_edges = _build_themes(pair_counts, term_map)
  local edges = _build_scrap_edges(scraps)
  for _, edge in ipairs(theme_edges) do
    edges[#edges + 1] = edge
  end

  return {
    metadata = {
      schema_version = 1,
      engine = "lua",
      project_name = config.project_name or "scrap4lua",
      project_root = project_root,
      scrap_count = #scraps,
      collection_count = #(config.collections or {}),
    },
    scraps = scraps,
    terms = _sorted_term_entries(term_map),
    themes = themes,
    edges = edges,
    warnings = warnings,
    aliases = alias_map,
    collection_weights = _clone_map(config.scoring.collection_weights),
  }
end

return indexer
