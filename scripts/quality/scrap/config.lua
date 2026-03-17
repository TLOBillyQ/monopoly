local migration_pairs = require("tests.support.migration_pairs")

local aliases = {
  choice = { "owner_role_id", "pending_choice", "choice_id" },
  bankruptcy = { "bankruptcy_feedback_port", "tiles_cleared" },
  market = { "paid_purchase_gateway", "product_id", "price" },
  ["src.game.systems"] = { "src.rules" },
  ["src.game.ports"] = { "src.rules.ports" },
}

for _, pair in ipairs(migration_pairs.iter_pairs()) do
  aliases[pair.old_module] = aliases[pair.old_module] or {}
  aliases[pair.old_module][#aliases[pair.old_module] + 1] = pair.new_module

  aliases[pair.new_module] = aliases[pair.new_module] or {}
  aliases[pair.new_module][#aliases[pair.new_module] + 1] = pair.old_module
end

return {
  project_name = "Monopoly",
  project_root = REPO_ROOT or ".",
  collections = {
    {
      name = "code",
      kind = "code",
      roots = { "src", "scripts/quality" },
      include = { ".lua" },
      exclude = { "vendor/", "tmp/", ".git/", "scripts/quality/arch/viewer/" },
      extract = {
        file = true,
        functions = true,
        requires = true,
      },
    },
    {
      name = "test",
      kind = "test",
      roots = { "tests" },
      include = { ".lua" },
      exclude = { "tmp/", "vendor/", ".git/" },
      extract = {
        file = true,
        functions = true,
        requires = true,
      },
    },
    {
      name = "doc",
      kind = "doc",
      roots = { "docs/architecture" },
      include = { ".md" },
      exclude = { "tmp/", "vendor/", ".git/" },
      extract = {
        file = true,
        headings = true,
      },
    },
  },
  glossary = {
    aliases = aliases,
    stop_words = {
      "state",
      "value",
      "result",
      "common",
      "utils",
      "index",
      "data",
      "path",
      "local",
      "function",
      "return",
    },
  },
  scoring = {
    collection_weights = {
      code = 1.0,
      test = 0.8,
      doc = 0.7,
    },
  },
}
