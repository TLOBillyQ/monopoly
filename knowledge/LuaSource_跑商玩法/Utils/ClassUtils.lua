-- 定义一个名为 ClassUtils 的空表
local ClassUtils = {}

-- 定义一个用于创建类的函数，接受类名和可选的父类作为参数
function ClassUtils.class(classname, super)
	-- 获取父类的类型
	local superType = type(super)
	-- 断言：确保父类要么是 nil，要么是一个表
	assert(super == nil or type(super) == "table", superType)

	local cls
	if super then
		-- 如果有父类，创建一个新表并设置元表，使其继承父类
		cls = {}
		setmetatable(cls, { __index = super })
		cls.super = super
	else
		-- 如果没有父类，创建一个空表
		cls = {}
	end

	-- 设置类的名称和索引
	cls.__cname = classname
	cls.__index = cls

	-- 定义类的构造函数
	function cls.new(...)
		-- 创建一个新的实例并设置其元表
		local instance = setmetatable({}, cls)

		-- 收集所有父类
		local child = cls
		local classes = { cls }
		while child.super do
			table.insert(classes, child.super)
			child = child.super
		end

		-- 从最顶层的父类开始，依次调用构造函数
		for i = #classes, 1, -1 do
			local ctor = rawget(classes[i], "ctor")
			if ctor then
				ctor(instance, ...)
			end
		end

		-- 返回新创建的实例
		return instance
	end

	-- 返回创建的类
	return cls
end

-- 返回 ClassUtils 表，使其可以被其他模块导入
return ClassUtils
