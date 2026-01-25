local class = require("Utils.ClassUtils").class
local Deque = require("Utils.Deque")

---@class FrameLoader 分帧加载器
---@field new fun(integer, integer): FrameLoader
---@field loadQueue Deque 加载队列
local FrameLoader = class("FrameLoader")

function FrameLoader:ctor(frameCount, frameInterval)
	self.frameCount = frameCount -- 每次加载的数量
	self.frameInterval = frameInterval -- 两次加载之间的帧间隔
	-- 加载列表用一个双端队列，先进先加载比较符合直觉
	self.loadQueue = Deque.new(64)
	self.frameTick = 0
	self.idGen = 0
end

function FrameLoader:_genId()
	self.idGen = self.idGen + 1
	return self.idGen
end

---分帧加载物体
---@param loadFunc function 见EggyAPI中的各种创建物体的参数
---@param callback function|nil 创建成功后的回调
---@param ... table 创建函数所需的参数列表
---@return integer id
function FrameLoader:load(loadFunc, callback, ...)
	local id = self:_genId()
	self.loadQueue:pushBack({ id = id, func = loadFunc, cb = callback, args = table.pack(...), dumped = false })
	return id
end

function FrameLoader:cancelLoad(id)
	if id < 0 then
		return
	end
	-- 取消加载只是设置成dumped，等实际加载到直接跳过
	local itor = self.loadQueue:ipairs()
	local item = itor()
	while item ~= nil do
		if item.id == id then
			item.dumped = true
			break
		end
		item = itor()
	end
end

function FrameLoader:update()
	if self.frameTick > 0 then
		self.frameTick = self.frameTick - 1
		return
	else
		self.frameTick = self.frameInterval
	end
	local loadCount = self.loadQueue:size()
	if loadCount == 0 then
		return
	end
	local frameCount = self.frameCount
	while loadCount ~= 0 and frameCount > 0 do
		local item = self.loadQueue:popFront()
		if item ~= nil and not item.dumped then
			local ret = item.func(table.unpack(item.args))
			if item.cb ~= nil then
				item.cb(ret)
			end
			frameCount = frameCount - 1
		end
		loadCount = loadCount - 1
	end
end

return FrameLoader
