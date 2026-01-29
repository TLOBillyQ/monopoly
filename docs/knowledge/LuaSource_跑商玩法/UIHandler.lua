-- 导入所需的模块
local class = require("Utils.ClassUtils").class
local UINodes = require("Data.UINodes")

-- 定义UIHandler类
---@class UIHandler
---@field new fun(): UIHandler
local UIHandler = class("UIHandler")

-- 构造函数
function UIHandler:ctor()
	-- 初始化按钮处理器映射
	self._role2BtnHandlers = {}

	-- 遍历所有有效角色
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		-- 隐藏商品操作按钮
		role.set_node_visible(UINodes["商品操作按钮"], false)
		-- 设置初始金币数量
		role.set_kv_by_type(Enums.ValueType.Int, "money", 200)
		-- 更新角色金币UI显示
		self:updateRoleMoneyUI(role)
	end

	-- 注册商品操作按钮点击事件
	LuaAPI.global_register_custom_event("点击商品操作按钮", function(_, _, data)
		local role_id = data.role_id
		local handler = self._role2BtnHandlers[role_id]
		if handler then
			handler()
		end
	end)
end

-- 更新玩家金币显示
function UIHandler:updateRoleMoneyUI(role)
	-- 获取角色当前金币数量
	local money = role.get_kv_by_type(Enums.ValueType.Int, "money")
	-- 更新金币数量显示
	role.set_label_text(UINodes["金币数量"], tostring(money))
end

-- 更新操作按钮文本和点击回调
function UIHandler:setItemOpHandler(role, text, handler)
	local btn = UINodes["商品操作按钮"]
	-- 根据文本是否为空来设置按钮可见性
	role.set_node_visible(btn, text ~= "")
	-- 设置按钮文本
	role.set_button_text(btn, text)
	-- 存储角色对应的按钮处理函数
	self._role2BtnHandlers[role.get_roleid()] = handler
end

-- 返回UIHandler类
return UIHandler
