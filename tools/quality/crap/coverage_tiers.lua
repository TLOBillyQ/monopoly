return {
  tiers = {
    {
      name = "core_logic",
      threshold = 0.90,
      includes = {
        "src/app/",
        "src/computer/",
        "src/config/",
        "src/core/",
        "src/player/",
        "src/rules/",
        "src/state/",
        "src/turn/",
      },
    },
    {
      name = "host_bridge",
      threshold = 0.60,
      includes = { "src/host/" },
    },
    {
      name = "ui_surface",
      threshold = 0.70,
      includes = { "src/ui/" },
    },
  },
}
