---@class Utils
Utils = {}

UINT32_MAX = 0xFFFFFFFF
UINT16_MAX = 0xFFFF
UINT8_MAX = 0xFF
UINT4_MAX = 0xF
INT64MAX = 0x7FFFFFFFFFFFFFFF
INT32_MAX = 0x7FFFFFFF
INT16_MAX = 0x7FFF
INT8_MAX = 0x7F
INT4_MAX = 0x7

---@class bigint
---@field sign integer
---@field digits integer[]

---@class Frameout
---@field frame integer 当前帧数
---@field left_count integer 剩余次数
---@field status boolean 状态
---@field destroy fun() 销毁计时器
---@field pause fun() 暂停计时器
---@field resume fun() 恢复计时器

---@param interval integer 计时间隔（单位：帧）
---@param callback fun(frameout: Frameout) 回调函数
---@param count integer? 重复次数，-1为无限次
---@param immediately boolean? 是否立即执行回调
SetFrameOut = function(interval, callback, count, immediately)
    count = count or 1
    ---@type Frameout
    local frameout = {}
    frameout.frame = 0
    frameout.left_count = count
    frameout.status = true
    local decorator = function()
        frameout.frame = frameout.frame + interval
        if count > 0 then
            frameout.left_count = frameout.left_count - 1
        end
        callback(frameout)
        if frameout and count > 0 and (frameout.left_count == 0) then
            frameout.destroy()
        end
    end
    local handler = RegisterTriggerEvent(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(interval) / 30.0 }, decorator
    )
    ---销毁计时器
    frameout.destroy = function()
        LuaAPI.global_unregister_trigger_event(handler)
        frameout = nil
    end
    ---暂停计时器
    frameout.pause = function()
        if frameout.status then
            LuaAPI.global_unregister_trigger_event(handler)
            frameout.status = false
        end
    end
    ---恢复计时器
    frameout.resume = function()
        if not frameout.status then
            handler = RegisterTriggerEvent(
                { EVENT.REPEAT_TIMEOUT, math.tofixed(interval) / 30.0 }, decorator
            )
            frameout.status = true
        end
    end
    if immediately then
        decorator()
    end
    return frameout
end

---@generic T
---@param ... T
---@return T
---从给定参数中随机选择一个元素
function Utils.choice(...)
    local args = { ... }
    if #args == 0 then
        return nil
    end
    return args[GameAPI.random_int(1, #args)]
end

---@generic T
---@param array T[]
---@param indices integer[]
---@return T[] 被删除的元素列表
function Utils.remove_indices(array, indices)
    -- 对索引列表进行降序排序
    local result = {}
    table.sort(indices, function(a, b) return a > b end)

    -- 逐个删除元素
    for idx, index in ipairs(indices) do
        result[idx] = table.remove(array, index)
    end
    return result
end

---@generic T
---@param list T[] 输入列表
---@param N integer 抽取元素数量（默认为1）
---@param repeat_enable boolean 是否允许重复抽取（默认为false）
---@return T[] 返回单个元素或元素列表
---从列表中随机抽取元素
function Utils.choice_list(list, N, repeat_enable)
    if not list or #list == 0 then
        return {}
    end

    -- 设置默认值
    N = N or 1
    repeat_enable = repeat_enable or false ---@type boolean

    -- 处理不允许重复且N大于列表长度的情况
    if not repeat_enable and N > #list then
        N = #list
    end

    -- 抽取单个元素
    if N == 1 then
        return { list[GameAPI.random_int(1, #list)] }
    end

    -- 抽取多个元素
    local result = {}

    if repeat_enable then
        -- 允许重复抽取
        for i = 1, N do
            table.insert(result, list[GameAPI.random_int(1, #list)])
        end
    else
        -- 不允许重复抽取（洗牌算法）
        local shuffled = {}
        for i, v in ipairs(list) do
            shuffled[i] = v
        end

        -- Fisher-Yates洗牌算法
        for i = #shuffled, 2, -1 do
            local j = GameAPI.random_int(1, i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        -- 取前N个元素
        for i = 1, N do
            table.insert(result, shuffled[i])
        end
    end

    return result
end

---@generic T
---@param orig T
---@return T
function Utils.deep_copy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for key, value in pairs(orig) do
        -- 只处理 integer 或 string 类型的键
        if type(key) == "number" then
            -- 整数键：递归拷贝值
            copy[key] = Utils.deep_copy(value)
        elseif type(key) == "string" then
            -- 字符串键：递归拷贝值
            copy[key] = Utils.deep_copy(value)
        end
        -- 其他类型的键（如 float、boolean 等）会被忽略
    end
    return copy
end

---@generic T
---@param array T[]
---@param predicate fun(item: T): boolean
---@return T?
function Utils.array_find(array, predicate)
    for _, item in ipairs(array) do
        if predicate(item) then
            return item
        end
    end
end

---@generic T
---@param array T[]
---@param predicate fun(item: T): boolean
---@return integer
function Utils.array_find_index(array, predicate)
    for index, item in ipairs(array) do
        if predicate(item) then
            return index
        end
    end
    return -1
end

---@generic C
---@generic T
---@param _table table<C, T>
---@param predicate fun(item: T): boolean
---@return T?
function Utils.table_find(_table, predicate)
    for key, value in pairs(_table) do
        if predicate(value) then
            return value
        end
    end
end

---@generic C, T
---@param _table table<C, T>
---@param predicate fun(item: T): boolean
---@return C?
function Utils.table_find_key(_table, predicate)
    for key, value in pairs(_table) do
        if predicate(value) then
            return key
        end
    end
end

-- ============================================================================
-- 路径平滑插值工具函数
-- ============================================================================

---三次贝塞尔曲线插值函数
---@param t number 插值参数 [0, 1]
---@param p0 Vector3 起始点
---@param p1 Vector3 控制点1
---@param p2 Vector3 控制点2
---@param p3 Vector3 终点
---@return Vector3
function Utils.cubic_bezier(t, p0, p1, p2, p3)
    local u = 1 - t
    local tt = t * t
    local uu = u * u
    local uuu = uu * u
    local ttt = tt * t

    -- B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
    local result = p0 * uuu + p1 * (3 * uu * t) + p2 * (3 * u * tt) + p3 * ttt
    return result
end

---Catmull-Rom样条插值
---@param t number 插值参数 [0, 1]
---@param p0 Vector3 点0
---@param p1 Vector3 点1
---@param p2 Vector3 点2
---@param p3 Vector3 点3
---@return Vector3
function Utils.catmull_rom_interpolation(t, p0, p1, p2, p3)
    local t2 = t * t
    local t3 = t2 * t

    -- Catmull-Rom公式
    local result = p1 * (2 * t3 - 3 * t2 + 1) +
        p2 * (-2 * t3 + 3 * t2) +
        (p2 - p0) * (t3 - 2 * t2 + t) * 0.5 +
        (p3 - p1) * (t3 - t2) * 0.5

    return result
end

---计算平滑控制点
---@param prev Vector3? 前一个点
---@param current Vector3 当前点
---@param next Vector3? 后一个点
---@param tension number 张力系数 [0, 1], 0为完全平滑，1为原始角度
---@return Vector3, Vector3 返回控制点1和控制点2
function Utils.calculate_control_points(prev, current, next, tension)
    tension = tension or 0.3

    local control1, control2

    if prev and next then
        -- 计算切线方向
        local tangent = (next - prev) * 0.5
        control1 = current - tangent * tension
        control2 = current + tangent * tension
    elseif prev then
        -- 只有前一个点
        local direction = (current - prev):normalize()
        local distance = (current - prev):length() * tension
        control1 = current - direction * distance
        control2 = current + direction * distance
    elseif next then
        -- 只有后一个点
        local direction = (next - current):normalize()
        local distance = (next - current):length() * tension
        control1 = current - direction * distance
        control2 = current + direction * distance
    else
        -- 没有相邻点，使用当前点
        control1 = current
        control2 = current
    end

    return control1, control2
end

---使用贝塞尔曲线平滑路径
---@param waypoints Vector3[] 原始路径点数组
---@param segments_per_curve number 每段曲线的分段数
---@param tension number 平滑张力系数 [0, 1]
---@return Vector3[] 平滑后的路径点数组
function Utils.smooth_path_bezier(waypoints, segments_per_curve, tension)
    if not waypoints or #waypoints < 2 then
        return waypoints or {}
    end

    segments_per_curve = segments_per_curve or 10
    tension = tension or 0.3

    local smoothed_path = {}

    -- 如果只有两个点，直接线性插值
    if #waypoints == 2 then
        for i = 0, segments_per_curve do
            local t = i / segments_per_curve
            local interpolated = waypoints[1] * (1 - t) + waypoints[2] * t
            table.insert(smoothed_path, interpolated)
        end
        return smoothed_path
    end

    -- 多个点使用贝塞尔曲线平滑
    for i = 1, #waypoints - 1 do
        local p0 = waypoints[i] --[[@as Vector3]]
        local p3 = waypoints[i + 1] --[[@as Vector3]]

        -- 计算控制点
        local prev = i > 1 and waypoints[i - 1] or nil
        local next = i + 2 <= #waypoints and waypoints[i + 2] or nil

        local _, p1 = Utils.calculate_control_points(prev, p0, waypoints[i + 1], tension)
        local p2, _ = Utils.calculate_control_points(waypoints[i], p3, next, tension)

        -- 生成曲线上的点
        local curve_segments = (i == #waypoints - 1) and segments_per_curve or segments_per_curve - 1
        for j = 0, curve_segments do
            local t = j / segments_per_curve
            local point = Utils.cubic_bezier(t, p0, p1, p2, p3)
            table.insert(smoothed_path, point)
        end
    end

    return smoothed_path
end

---使用Catmull-Rom样条平滑路径
---@param waypoints Vector3[] 原始路径点数组
---@param segments_per_curve number 每段曲线的分段数
---@return Vector3[] 平滑后的路径点数组
function Utils.smooth_path_catmull_rom(waypoints, segments_per_curve)
    if not waypoints or #waypoints < 2 then
        return waypoints or {}
    end

    segments_per_curve = segments_per_curve or 10
    local smoothed_path = {}

    if #waypoints == 2 then
        -- 只有两个点，线性插值
        for i = 0, segments_per_curve do
            local t = i / segments_per_curve
            local point = waypoints[1] * (1 - t) + waypoints[2] * t
            table.insert(smoothed_path, point)
        end
        return smoothed_path
    end

    -- 添加第一个点
    table.insert(smoothed_path, waypoints[1])

    -- 对每个内部段进行插值
    for i = 2, #waypoints - 1 do
        local p0 = waypoints[i - 1] --[[@as Vector3]]
        local p1 = waypoints[i] --[[@as Vector3]]
        local p2 = waypoints[i + 1] --[[@as Vector3]]
        local p3 = i + 2 <= #waypoints and waypoints[i + 2] or waypoints[i + 1] --[[@as Vector3]]

        for j = 1, segments_per_curve do
            local t = j / segments_per_curve
            local point = Utils.catmull_rom_interpolation(t, p0, p1, p2, p3)
            table.insert(smoothed_path, point)
        end
    end

    return smoothed_path
end

---通用路径平滑函数
---@param waypoints Vector3[] 原始路径点数组
---@param smooth_type string 平滑类型："bezier" 或 "catmull_rom"
---@param segments_per_curve number? 每段曲线的分段数，默认10
---@param tension number? 贝塞尔曲线的张力系数 [0, 1]，默认0.3
---@return Vector3[] 平滑后的路径点数组
function Utils.smooth_path(waypoints, smooth_type, segments_per_curve, tension)
    smooth_type = smooth_type and smooth_type or "bezier"
    segments_per_curve = segments_per_curve or 10
    tension = tension or 0.3

    if smooth_type == "catmull_rom" then
        return Utils.smooth_path_catmull_rom(waypoints, segments_per_curve)
    else -- 默认使用贝塞尔曲线
        return Utils.smooth_path_bezier(waypoints, segments_per_curve, tension)
    end
end

-- ============================================================================
-- 其他数学工具函数
-- ============================================================================

---线性插值
---@param a number 起始值
---@param b number 结束值
---@param t number 插值参数 [0, 1]
---@return number
function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

---Vector3线性插值
---@param a Vector3 起始向量
---@param b Vector3 结束向量
---@param t number 插值参数 [0, 1]
---@return Vector3
function Utils.lerp_vector3(a, b, t)
    return a * (1 - t) + b * t
end

---限制值在指定范围内
---@param value number 要限制的值
---@param min number 最小值
---@param max number 最大值
---@return number
function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

---将值从一个范围映射到另一个范围
---@param value number 输入值
---@param in_min number 输入范围最小值
---@param in_max number 输入范围最大值
---@param out_min number 输出范围最小值
---@param out_max number 输出范围最大值
---@return number
function Utils.map_range(value, in_min, in_max, out_min, out_max)
    return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)
end

---平滑步进函数（S曲线）
---@param edge0 number 下边界
---@param edge1 number 上边界
---@param x number 输入值
---@return number 0到1之间的平滑值
function Utils.smoothstep(edge0, edge1, x)
    x = Utils.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return x * x * (3 - 2 * x)
end

--- 权重池抽取函数
---@generic T
---@param _array T[] 数组
---@param _count integer 抽取数量
---@param _callback fun(e: T): integer 权重计算回调函数
---@param _repeatable boolean 是否允许重复抽取
---@return T[] 抽取结果
function Utils.choice_weight_list(_array, _count, _callback, _repeatable)
    if #_array == 0 or _count <= 0 then
        return {}
    end

    -- 计算总权重并构建权重数组
    local total_weight = 0
    local weights = {}

    for i, element in ipairs(_array) do
        local weight = _callback(element)
        if weight < 0 then
            weight = 0
        end
        weights[i] = weight
        total_weight = total_weight + weight
    end

    -- 如果总权重为0，则无法进行权重抽取
    if total_weight <= 0 then
        return {}
    end

    local result = {}

    if _repeatable then
        -- 有放回抽取
        for i = 1, _count do
            local rand = LuaAPI.rand() * total_weight
            local accumulated = 0

            for j, element in ipairs(_array) do
                accumulated = accumulated + weights[j]
                if accumulated >= rand then
                    table.insert(result, element)
                    break
                end
            end
        end
    else
        -- 无放回抽取
        local temp_weights = {}
        for i, w in ipairs(weights) do
            temp_weights[i] = w
        end
        local temp_total = total_weight

        for i = 1, math.min(_count, #_array) do
            if temp_total <= 0 then
                break
            end

            local rand = LuaAPI.rand() * temp_total
            local accumulated = 0

            for j, element in ipairs(_array) do
                if temp_weights[j] > 0 then
                    accumulated = accumulated + temp_weights[j]
                    if accumulated >= rand then
                        table.insert(result, element)
                        temp_total = temp_total - temp_weights[j]
                        temp_weights[j] = 0 -- 标记为已抽取
                        break
                    end
                end
            end
        end
    end

    return result
end

-- 辅助函数：规范化大整数（去除高位0并处理0的符号）
local function normalize(bigint)
    local digits = bigint.digits
    local index = 1
    while #digits > 0 and digits[#digits] == 0 or (index >= 5) do
        table.remove(digits)
        index = index + 1
    end
    if #digits == 0 then
        bigint.sign = 1
        table.insert(digits, 0)
    end
    return bigint
end

-- 辅助函数：比较两个大整数的绝对值大小（仅比较数字部分）
local function compare_abs(a_digits, b_digits)
    if #a_digits ~= #b_digits then
        return #a_digits > #b_digits and 1 or -1
    end
    for i = #a_digits, 1, -1 do
        if a_digits[i] ~= b_digits[i] then
            return a_digits[i] > b_digits[i] and 1 or -1
        end
    end
    return 0
end

-- 辅助函数：绝对值加法（要求a_digits和b_digits非负）
local function add_abs(a_digits, b_digits)
    local result = {}
    local carry = 0
    local max_len = math.max(#a_digits, #b_digits)

    for i = 1, max_len do
        local a_val = a_digits[i] or 0
        local b_val = b_digits[i] or 0
        local total = a_val + b_val + carry
        carry = total >= 0x100000000 and 1 or 0
        result[i] = total % 0x100000000
    end

    if carry > 0 then
        table.insert(result, carry)
    end
    return result
end

-- 辅助函数：绝对值减法（要求|a|>=|b|，结果非负）
local function sub_abs(a_digits, b_digits)
    local result = {}
    local borrow = 0

    for i = 1, #a_digits do
        local a_val = a_digits[i]
        local b_val = b_digits[i] or 0
        local total = a_val - b_val - borrow

        if total < 0 then
            borrow = 1
            total = total + 0x100000000
        else
            borrow = 0
        end

        result[i] = total
    end

    return normalize({ sign = 1, digits = result }).digits
end

-- 大整数加法
---@param a bigint
---@param b bigint
---@return bigint
function Utils.bigint_add(a, b)
    -- 同号处理
    if a.sign == b.sign then
        return normalize({
            sign = a.sign,
            digits = add_abs(a.digits, b.digits)
        })
    end

    -- 异号处理：转换为减法
    local cmp = compare_abs(a.digits, b.digits)
    if cmp == 0 then
        return { sign = 1, digits = { 0 } } -- 结果为0
    elseif cmp > 0 then
        return normalize({
            sign = a.sign,
            digits = sub_abs(a.digits, b.digits)
        })
    else
        return normalize({
            sign = b.sign,
            digits = sub_abs(b.digits, a.digits)
        })
    end
end

-- 大整数减法
---@param a bigint
---@param b bigint
---@return bigint
function Utils.bigint_sub(a, b)
    -- 将b取反后加法
    local neg_b = { sign = -b.sign, digits = b.digits }
    return Utils.bigint_add(a, neg_b)
end

-- 大整数比较（a<b返回-1，a==b返回0，a>b返回1）
---@param a bigint
---@param b bigint
function Utils.bigint_compare(a, b)
    -- 符号不同
    if a.sign ~= b.sign then
        return a.sign < b.sign and -1 or 1
    end

    -- 同号比较绝对值
    local cmp_abs = compare_abs(a.digits, b.digits)
    if a.sign > 0 then
        return cmp_abs
    else
        return -cmp_abs -- 负数时结果相反
    end
end

-- 大整数转十进制字符串
---@param bigint bigint
---@return string
-- 大整数转十进制字符串（修复死循环问题）
-- 正确的大整数转十进制字符串实现
function Utils.bigint_to_dec(bigint)
    -- 处理零值
    if #bigint.digits == 1 and bigint.digits[1] == 0 then
        return "0"
    end

    local result = {}
    local current = { sign = 1, digits = {} }

    -- 深拷贝原始数据
    for i, v in ipairs(bigint.digits) do
        current.digits[i] = v
    end

    -- 检查是否为0
    local function is_zero(digits)
        for _, v in ipairs(digits) do
            if v ~= 0 then return false end
        end
        return true
    end

    -- 长除法转换十进制
    while not is_zero(current.digits) do
        local carry = 0
        local new_digits = {}

        -- 从最高位开始处理
        for i = #current.digits, 1, -1 do
            local val = current.digits[i] + carry * 0x100000000
            carry = val % 10
            local quot = math.floor(val / 10)

            if quot > 0 or #new_digits > 0 then
                table.insert(new_digits, 1, quot)
            end
        end

        -- 添加当前十进制位
        table.insert(result, 1, math.tointeger(carry))

        -- 准备下一轮迭代
        current.digits = new_digits
    end
    -- 构建结果字符串
    local str = table.concat(result)

    -- 添加符号
    if bigint.sign < 0 then
        str = "-" .. str
    end
    return str
end

---@generic T
---@param array T[]
---@param indices integer[]
---@return T[]
function Utils.array_remove_by_indices(array, indices)
    local mark = {}
    local length = #array
    for _, idx in ipairs(indices) do
        -- 只处理有效范围内的整数索引（Lua 数组索引从 1 开始）
        if type(idx) == "number" and idx >= 1 and idx <= length and idx % 1 == 0 then
            mark[idx] = true
        end
    end

    -- 构建新数组（保留未被标记删除的元素）
    local result = {}
    for i = 1, length do
        if not mark[i] then
            table.insert(result, array[i])
        end
    end

    return result
end

---@param str string
---@param sep string
---@return string[]
function Utils.split_string(str, sep)
    local result = {}
    for part in str:gmatch("[^" .. sep .. "]+") do
        table.insert(result, part)
    end
    return result
end
