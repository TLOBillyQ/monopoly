---预设
Prefab = require "Data.Prefab"

require 'Globals.__init'

---所有玩家

---全局变量
require 'Library.Utils' ---工具函数
require 'Library.ClassUtils'

---UI界面
require 'Library.UIManager.Utils'
UINodes = require "Data.UINodes"
UIManager.Builder:new(require "Data.UIManagerNodes")

---存档
Archives = require "Data.ArchivesData"
Bincore = require 'Library.Bincore'

---行为树
Behavior = require 'Library.Behavior.config'

---管理器
require 'Manager.__init'

---初始化数据
---@class LevelData
---@field current_level string
---@field current_select_level string
---@field current_mode? string
---@field [RoleID] {escaper_code?: EscaperCode}
LevelData = LevelData or {
    current_level = "lobby",
    current_select_level = "death_station"
}

for _, role in ipairs(ALLROLES) do
    LevelData[role.get_name()] = LevelData[role.get_name()] or {}
end