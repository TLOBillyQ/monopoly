return {
  project_name = "Monopoly",
  project_root = REPO_ROOT or ".",
  collections = {
    {
      name = "code",
      kind = "code",
      roots = { "src", "tools/quality" },
      include = { ".lua" },
      exclude = { "vendor/", "tmp/", ".git/", "tools/quality/arch/viewer/" },
      extract = {
        file = true,
        functions = true,
        requires = true,
      },
    },
    {
      name = "test",
      kind = "test",
      roots = { "spec" },
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
