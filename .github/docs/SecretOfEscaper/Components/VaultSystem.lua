---@class VaultSystem
---@field balances table<string, Fixed> -- 货币类型为键，余额为值
---@field new fun(self: VaultSystem, balances: table<string, Fixed>): VaultSystem
local VaultSystem = Class("VaultSystem")

---@param balances table<string, Fixed> -- 货币类型为键，余额为值
function VaultSystem:init(balances)
    self.balances = balances or {} -- 货币类型为键，余额为值
end

-- 存款
---@param currency string
---@param amount Fixed
---@return boolean
function VaultSystem:deposit(currency, amount)
    if amount <= 0 then
        warn("amount must be positive")
        return false
    end
    self.balances[currency] = (self.balances[currency] or 0) + amount
    return true
end

-- 取款
---@param currency string
---@param amount Fixed
---@return boolean
function VaultSystem:withdraw(currency, amount)
    if amount <= 0 then
        warn("amount must be positive")
        return false
    end
    local current = self.balances[currency] or 0
    if current < amount then
        warn("not enough balance")
        return false
    end
    self.balances[currency] = current - amount
    return true
end

-- 查询余额
---@param currency string
---@return Fixed
function VaultSystem:get_balance(currency)
    return self.balances[currency] or 0
end

-- 转账到另一个经济系统
---@param to_economy VaultSystem
---@param currency string
---@param amount Fixed
---@return boolean
function VaultSystem:transfer_to(to_economy, currency, amount)
    if amount <= 0 then
        warn("amount must be positive")
        return false
    end
    -- 先从当前账户取款
    local success = self:withdraw(currency, amount)
    if not success then
        return false
    end
    -- 然后存款到目标账户
    success = to_economy:deposit(currency, amount)
    if not success then
        -- 存款失败，回滚取款
        self:deposit(currency, amount)
        return false
    end
    return true
end

-- 导出数据
---@return table<string, Fixed>
function VaultSystem:export()
    return self.balances
end

---@param role Role
---@param currency string
---@param amount integer
---@param label UIManager.ELabel
function VaultSystem:update_render(role, currency, amount, label)
    local temp = UIManager.client_role
    UIManager.client_role = role
    local balance = self:get_balance(currency)
    if amount == 0 then
        label.text = ("%d"):format(math.tointeger(balance))
        return
    end
    local result_balance = balance + amount
    label.text = ("%s %s %s = %s"):format(
        ("#f(c:ffff00)%d#l"):format(balance),
        amount < 0 and "-" or "+",
        ("#f(c:%s)%d#l"):format(
            amount < 0 and "ff0000" or "00ff00",
            math.abs(amount)
        ),
        ("#f(c:%s)%d#l"):format(
            result_balance < 0 and "ff0000" or "00ff00",
            result_balance
        )
    )
    UIManager.client_role = temp
end

return VaultSystem