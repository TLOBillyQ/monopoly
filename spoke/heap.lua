-- Heap.lua
-- A min-heap data structure for priority queue operations

local Heap = {}
Heap.__index = Heap

function Heap.new(comparison)
    if type(comparison) ~= "function" then
        error("Heap requires a comparison function")
    end
    local self = setmetatable({}, Heap)
    self.heap = {}
    self.comparison = comparison
    return self
end

function Heap:Count()
    return #self.heap
end

function Heap:Insert(value)
    if value == nil then
        error("Cannot insert nil value into heap")
    end
    table.insert(self.heap, value)
    self:HeapifyUp(#self.heap)
end

function Heap:RemoveMin()
    if #self.heap == 0 then
        error("Cannot remove from empty heap")
    end
    local min = self.heap[1]
    self:RemoveAt(1)
    return min
end

function Heap:PeekMin()
    if #self.heap == 0 then
        error("Cannot peek into empty heap")
    end
    return self.heap[1]
end

function Heap:RemoveAt(index)
    if index < 1 or index > #self.heap then
        error("Index out of bounds: " .. tostring(index))
    end
    local lastIndex = #self.heap
    if index ~= lastIndex then
        self:Swap(index, lastIndex)
    end
    table.remove(self.heap, lastIndex)
    if index <= #self.heap then
        self:HeapifyDown(index)
    end
end

function Heap:HeapifyUp(index)
    local heap = self.heap
    local item = heap[index]
    local comparison = self.comparison
    local parent = math.floor((index - 1) / 2) + 1  -- Lua is 1-indexed
    
    while index > 1 and comparison(item, heap[parent]) < 0 do
        heap[index] = heap[parent]
        index = parent
        parent = math.floor((index - 1) / 2) + 1
    end
    heap[index] = item
end

function Heap:HeapifyDown(index)
    local heap = self.heap
    local heapSize = #heap
    local comparison = self.comparison
    
    while true do
        local leftChild = 2 * index
        local rightChild = 2 * index + 1
        local smallest = index
        
        if leftChild <= heapSize and comparison(heap[leftChild], heap[smallest]) < 0 then
            smallest = leftChild
        end
        if rightChild <= heapSize and comparison(heap[rightChild], heap[smallest]) < 0 then
            smallest = rightChild
        end
        if smallest == index then
            break
        end
        self:Swap(index, smallest)
        index = smallest
    end
end

function Heap:Swap(i, j)
    local tmp = self.heap[i]
    self.heap[i] = self.heap[j]
    self.heap[j] = tmp
end

return Heap
