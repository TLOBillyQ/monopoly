local class = require("Utils.ClassUtils").class

---@class Deque
---@field new fun(capacity: integer)
local Deque = class("Deque")

-- 创建新双端队列
function Deque:ctor(capacity)
	local DEFAULT_CAPACITY = 8
	self._capacity = math.max(capacity or DEFAULT_CAPACITY, 4) -- 当前缓冲区容量
	self._data = {}
	self._head = 0 -- 虚拟头指针（总指向下一个可插入位置）
	self._tail = 1 -- 虚拟尾指针
	self._size = 0 -- 当前元素数量
end

function Deque:_resize(newCapacity)
	local newData = {}
	for i = 1, self._size do
		newData[i] = self:get(i)
	end
	self._data = newData
	self._head = 0
	self._tail = self._size + 1
	self._capacity = newCapacity
end

-- 头部插入
function Deque:pushFront(value)
	if self._size == self._capacity then
		self:_resize(self._capacity * 2)
	end
	self._data[self._head] = value
	self._head = (self._head - 1) % self._capacity
	self._size = self._size + 1
end

-- 尾部插入
function Deque:pushBack(value)
	if self._size == self._capacity then
		self:_resize(self._capacity * 2)
	end
	self._data[self._tail] = value
	self._tail = (self._tail + 1) % self._capacity
	self._size = self._size + 1
end

-- 头部删除
function Deque:popFront()
	if self._size == 0 then
		return nil
	end
	self._head = (self._head + 1) % self._capacity
	local value = self._data[self._head]
	self._data[self._head] = nil
	self._size = self._size - 1

	if self._capacity > 8 and self._size < self._capacity // 4 then
		self:_resize(math.max(8, self._capacity // 2))
	end

	return value
end

-- 尾部删除
function Deque:popBack()
	if self._size == 0 then
		return nil
	end
	self._tail = (self._tail - 1) % self._capacity
	local value = self._data[self._tail]
	self._data[self._tail] = nil
	self._size = self._size - 1

	if self._capacity > 8 and self._size < self._capacity // 4 then
		self:_resize(math.max(8, self._capacity // 2))
	end

	return value
end

-- 获取头部元素（不删除）
function Deque:front()
	return self._data[self._head]
end

-- 获取尾部元素（不删除）
function Deque:back()
	return self._data[self._tail]
end

-- 队列元素数量
function Deque:size()
	return self._size
end

-- 判断队列是否为空
function Deque:isEmpty()
	return self._size == 0
end

-- 清空队列
function Deque:clear()
	for i = self._head, self._tail do
		self._data[i] = nil
	end
	self._head = 0
	self._tail = 1
	self._size = 0
end

-- 随机访问元素
function Deque:get(index)
	if index < 1 or index > self._size then
		error("Index out of bound")
	end
	local physical_index = (self._head + index) % self._capacity
	return self._data[physical_index]
end

-- 随机修改元素
function Deque:set(index, value)
	if index < 1 or index > self._size then
		error("Index out of bound")
	end
	local physical_index = (self._head + index) % self._capacity
	self._data[physical_index] = value
end

-- 迭代器（正序）
function Deque:ipairs()
	local i = self._head
	return function()
		i = i + 1
		if i <= self._tail then
			return self._data[i]
		end
	end
end

-- 迭代器（逆序）
function Deque:ripairs()
	local i = self._tail
	return function()
		i = i - 1
		if i >= self._head then
			return self._data[i]
		end
	end
end

return Deque
