-- 单源真值：behavior warn 白名单
-- 与 docs/reports/behavior-warns.md 同步
return {
  whitelist = {
    ["[MarketDebug] apply_navigation rejected: invalid owner_role_id"] = true,
    ["[MarketDebug] apply_navigation rejected: player not found"] = true,
    ["[MarketDebug] apply_navigation rejected: build returned nil"] = true,
    ["market paid purchase blocked:"] = true,
    ["choice action missing actor_role_id:"] = true,
    ["choice action blocked by actor check:"] = true,
    ["auto runner produced no action for runtime pending choice"] = true,
  }
}
