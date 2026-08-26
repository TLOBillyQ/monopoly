local dsl = require("packages.acceptance.step_dsl")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local leaderboard = require("src.app.host_integrations.leaderboard")
-- 排行榜域绑定（#192 簇 B）：真实 leaderboard.settle 跑在内存存档端口上。
local WIN, ASSETS = leaderboard.win_count_archive_key, leaderboard.total_assets_archive_key
local function _slot(role_id, key) return tostring(role_id) .. "|" .. tostring(key) end
local function _ensure(w)
  if w.lb then return w.lb end
  local lb = {
    store = {}, writes = 0, enabled = true, by_id = {},
    game = { players = {}, winners = {}, player_cash = function(_, p) return p.cash or 0 end,
      board = { get_tile_by_id = function() return nil end } },
  }
  runtime_ports.configure({
    archives_enabled = function() return lb.enabled end,
    get_archive_int = function(role_id, key) return lb.store[_slot(role_id, key)] or 0 end,
    set_archive_int = function(role_id, key, value) lb.store[_slot(role_id, key)], lb.writes = value, lb.writes + 1 end,
  })
  w.lb = lb
  return lb
end
local function _player(w, id)
  local lb = _ensure(w)
  if lb.by_id[id] == nil then
    lb.by_id[id] = { id = id, name = "P" .. tostring(id), properties = {}, cash = 0 }
    lb.game.players[#lb.game.players + 1] = lb.by_id[id]
  end
  return lb.by_id[id]
end
local function _seed(w, id, key, value) _ensure(w).store[_slot(id, key)] = value end
local function _stored(w, id, key) return _ensure(w).store[_slot(id, key)] or 0 end
local function _settle(w) leaderboard.settle(_ensure(w).game); return true end
return dsl.steps({
  ["玩家本局之前的胜利次数为<之前胜利次数:int>"] = function(w, a) _player(w, 1); _seed(w, 1, WIN, a["之前胜利次数"]) end,
  ["玩家本局<胜负结果>"] = function(w, a)
    local p = _player(w, 1)
    if a["胜负结果"] == "获胜" then w.lb.game.winners = { p }
    elseif a["胜负结果"] == "未获胜" then w.lb.game.winners = {}
    else return nil, "未知胜负结果: " .. tostring(a["胜负结果"]) end
  end,
  ["排行榜结算执行"] = _settle, ["排行榜结算再次执行"] = _settle,
  ["玩家本局之后的胜利次数为<之后胜利次数:int>"] = function(w, a) return dsl.eq(_stored(w, 1, WIN), a["之后胜利次数"], "胜利次数") end,
  ["玩家本局之前的累计资产为<之前累计资产:int>"] = function(w, a) _player(w, 1); _seed(w, 1, ASSETS, a["之前累计资产"]) end,
  ["玩家本局结束时仍在场"] = function(w) _player(w, 1).quit_reason = nil end,
  ["玩家本局结束时的剩余总资产为<本局剩余资产:int>"] = function(w, a) _player(w, 1).cash = a["本局剩余资产"] end,
  ["玩家本局之后的累计资产为<之后累计资产:int>"] = function(w, a) return dsl.eq(_stored(w, 1, ASSETS), a["之后累计资产"], "累计资产") end,
  ["玩家本局中途退出且退出时仍持有可观剩余资产"] = function(w) local p = _player(w, 1); p.cash, p.quit_reason = 99999, "disconnect" end,
  ["本局两名玩家并列获胜"] = function(w) _ensure(w).game.winners = { _player(w, 1), _player(w, 2) } end,
  ["每名获胜者本局之前的胜利次数为 2"] = function(w) _player(w, 1); _player(w, 2); _seed(w, 1, WIN, 2); _seed(w, 2, WIN, 2) end,
  ["每名获胜者本局之后的胜利次数为 3"] = function(w)
    for _, id in ipairs({ 1, 2 }) do
      local ok, err = dsl.eq(_stored(w, id, WIN), 3, "获胜者" .. tostring(id) .. " 胜利次数")
      if not ok then return nil, err end
    end
    return true
  end,
  ["玩家本局已完成排行榜结算"] = function(w)
    local p = _player(w, 1)
    p.cash, w.lb.game.winners = 50000, { p }
    leaderboard.settle(w.lb.game)
    w.lb_snapshot = { win = _stored(w, 1, WIN), assets = _stored(w, 1, ASSETS) }
  end,
  ["玩家的胜利次数不再增加"] = function(w) return dsl.eq(_stored(w, 1, WIN), w.lb_snapshot.win, "重复结算后胜利次数") end,
  ["玩家的累计资产不再增加"] = function(w) return dsl.eq(_stored(w, 1, ASSETS), w.lb_snapshot.assets, "重复结算后累计资产") end,
  ["宿主未开启自定义存档"] = function(w) local p = _player(w, 1); p.cash, w.lb.game.winners, w.lb.enabled = 50000, { p }, false end,
  ["不写入任何排行榜存档"] = function(w) return dsl.eq(_ensure(w).writes, 0, "存档写入次数") end,
}, { name = "leaderboard" })
