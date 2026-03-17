# scrap4lua

`scrap4lua` is a semantic navigation tool for Lua projects.
It builds a deterministic scrap index from code, tests, and docs, then answers queries like "where should I read first for concept X?".

## CLI

```sh
lua bin/scrap4lua index --config scrap4lua.config.lua --out tmp/scrap_index.json
lua bin/scrap4lua find --config scrap4lua.config.lua --query "choice owner_role_id"
lua bin/scrap4lua clusters --config scrap4lua.config.lua
lua bin/scrap4lua viewer --config scrap4lua.config.lua --out-dir tmp/scrap_view
```

## Commands

- `index`: scan configured collections and emit `ScrapIndex` JSON
- `find`: build an index in-memory and return ranked matches for a query
- `clusters`: build an index in-memory and return top semantic themes
- `viewer`: export a standalone static viewer bundle

## Config

`scrap4lua.config.lua` returns:

```lua
return {
  project_name = "Example",
  project_root = ".",
  collections = {
    {
      name = "code",
      kind = "code",
      roots = { "src" },
      include = { ".lua" },
      exclude = { "vendor/", "tmp/" },
      extract = { file = true, functions = true, requires = true },
    },
  },
  glossary = {
    aliases = {
      choice = { "owner_role_id" },
    },
    stop_words = { "state", "value" },
  },
  scoring = {
    collection_weights = {
      code = 1.0,
      test = 0.8,
      doc = 0.7,
    },
  },
}
```

## Output shape

`index` emits:
- `metadata`
- `scraps`
- `terms`
- `themes`
- `edges`
- `warnings`

`find` emits:
- `query`
- `expanded_terms`
- `matches`
- `explanations`

`viewer` exports:
- `index.html`
- `styles.css`
- `script.js`
- `scrap_index.json`
- `scrap_data.js`

## Design notes

- deterministic: no online learning, no random ordering
- semantic: aliases, migration mappings, and co-occurrence themes expand queries
- host-friendly: JSON is the public contract; viewer/TUI can be layered later
