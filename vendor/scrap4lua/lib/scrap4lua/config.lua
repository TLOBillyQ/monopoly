local config = {}

function config.load(path)
  local loaded = assert(loadfile(path))()
  assert(type(loaded) == "table", "scrap4lua config must return a table")
  loaded.collections = loaded.collections or {}
  loaded.glossary = loaded.glossary or {}
  loaded.glossary.aliases = loaded.glossary.aliases or {}
  loaded.glossary.stop_words = loaded.glossary.stop_words or {}
  loaded.scoring = loaded.scoring or {}
  loaded.scoring.collection_weights = loaded.scoring.collection_weights or {}
  return loaded
end

return config
