local VaultSystem = require "Components.VaultSystem"
local InventorySystem = require "Components.InventorySystem"
local AbilityManager = require "Manager.AbilityManager.__init"
local HealthSystem = require("Components.HealthSystem")
local EscaperFactory = require("Manager.EscaperManager.EscaperFactory")

---@class Player : Role
---@field role Role
---@field vault VaultSystem
---@field inventory InventorySystem
---@field equipment InventorySystem
---@field abilities AbilityManager
---@field custom_data table
---@field escaper? Escaper
---@field new fun(self: Player, role: Role): Player
local Player = Class("Player")


---元方法 - 元索引
function Player.__custom_index(tbl, key)
    local role = rawget(tbl, "role")
    if role and (type(role[key]) == "function") then
        return function(...)
            return role[key](...)
        end
    end
end

---@param role Role
function Player:init(role)
    self.role = role
    self.health_system = HealthSystem:new(5)
    self.abilities = AbilityManager:new(role)
    self.custom_data = {}
    self:load_data()
end

---@param escaper_code EscaperCode
function Player:set_escaper(escaper_code)
    LevelData[self.role.get_name()].escaper_code = escaper_code
    if self.escaper then
        self.escaper:destroy()
    end
    self.escaper = EscaperFactory.create(escaper_code, self, self.health_system)
end

local schema = {
    type = "table",
    fields = {
        {
            key = "vault",
            type = "table",
            fields = {
                { key = "coin",    type = "integer" },
                { key = "crystal", type = "integer" },
                { key = "diamond", type = "integer" }
            }
        },
        {
            key = "inventory",
            type = "array",
            element = {
                type = "table",
                fields = {
                    { key = "code", type = "string" },
                    {
                        key = "data",
                        type = "table",
                        fields = {
                            { key = "lasting", type = "integer" }
                        }
                    }
                }
            }
        },
        {
            key = "equipment",
            type = "array",
            element = {
                type = "table",
                fields = {
                    { key = "code", type = "string" },
                    {
                        key = "data",
                        type = "table",
                        fields = {
                            { key = "lasting", type = "integer" }
                        }
                    }
                }
            }
        }
    }
}

function Player:load_data()
    local result = ""
    for idx = 1001, 1100 do
        result = result .. self.role.get_archive_by_type(Enums.ArchiveType.Str, idx)
    end
    local status, data = pcall(Bincore.decode, result, schema)
    if not data or not status then
        data = {}
    end
    self.vault = VaultSystem:new(data.vault or {})
    self.inventory = InventorySystem:new(data.inventory or {})
    self.equipment = InventorySystem:new(data.equipment or {})
end

function Player:save_data()
    local data = {}
    data.vault = self.vault:export()
    data.inventory = self.inventory:export()
    data.equipment = self.equipment:export()
    local result = Bincore.encode(data, schema)
    ---切割成N份，每份64
    local len = #result
    local index = 1
    for i = 1, len, 64 do
        local batch = result:sub(i, math.min(i + 63, len))
        self.role.set_archive_by_type(Enums.ArchiveType.Str, 1000 + index, batch)
        index = index + 1
    end
end

return Player
