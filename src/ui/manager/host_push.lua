-- ui.manager.host_push — UIManager 子树推送宿主的公共形。
-- 每个 __update_* 都是同一件事:有 client_role 就只推给它,否则广播给 allroles。
-- 这段双分支原先在 6 个 manager 模块里手抄了 26 遍(dry4lua 满分重复簇),
-- 收敛到这里,让 __update_* 只留「推什么」,不再重复「推给谁」。
--
-- 取 context.allroles 用运行期读而非 load 期缓存:context.allroles 全仓只在
-- context.lua 赋值一次,子模块与 spec 都是原地增删同一张表,两种读法等价。
-- 不挂在 context 上是因为 utils 把 context 原表发布成全局 UIManager facade,
-- 挂上去等于给对外 facade 加一个内部帮手。
--
-- #542:宿主 role 代理存在个体差异(真机实测 AI 位 role=-4 缺
-- set_image_texture_by_key_with_auto_resize)。apply 拿到的 role 经判空代理
-- 包裹:方法在 → 原样转发,方法执行抛错照常上抛(#541 观测性不回退);方法
-- 缺失 → 跳过并 warn 留痕,不再炸 nil 调用,也不中断广播其余 role。
local context = require("src.ui.manager.context")
local role_id = require("src.foundation.identity")
local logger = require("src.foundation.log")

local host_push = {}

-- warn 里的 role 标识:优先规范化 roleid,取不到退回 tostring(role),
-- 事后仅凭日志可分辨是哪个角色的推送被跳过。
local function _role_label(role)
    if role ~= nil and role.get_roleid then
        local ok, raw_role_id = pcall(role.get_roleid)
        if ok then
            local normalized = role_id.normalize(raw_role_id)
            if normalized ~= nil then
                return tostring(normalized)
            end
        end
    end
    return tostring(role)
end

-- 缺失方法的替身:被调用时不推送,只留一条带 role 与方法名的 warn。
local function _missing_method_stub(role, method)
    return function()
        logger.warn("host_push skipped: role=" .. _role_label(role) .. " missing " .. tostring(method))
    end
end

local function _guard_role(role)
    return setmetatable({}, {
        __index = function(_, method)
            local fn = role[method]
            if type(fn) == "function" then
                return fn
            end
            return _missing_method_stub(role, method)
        end,
    })
end

--- 把一次宿主推送发给该发的角色。
--- 广播时按「每个角色依次执行 apply」推进,故 apply 内推多个宿主方法时,
--- 顺序是 role1.a、role1.b、role2.a、role2.b —— 与各 __update_* 原先手写
--- 双分支的调用顺序一致(EButton.__update_disabled 依赖这个顺序)。
---@param apply fun(role: Role)
function host_push.push(apply)
    if context.client_role then
        apply(_guard_role(context.client_role))
    else
        for _, role in ipairs(context.allroles) do
            apply(_guard_role(role))
        end
    end
end

return host_push

--[[ mutate4lua-manifest
version=4
projectHash=5030232bd86b99f4
scope.0.id=chunk:src/ui/manager/host_push.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=29bcce6ed576ea35
scope.1.id=function:_role_label
scope.1.kind=function
scope.1.startLine=23
scope.1.endLine=34
scope.1.semanticHash=03d2edbddfbccfe1
scope.2.id=function:_missing_method_stub
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=41
scope.2.semanticHash=12ec3f5b90f20483
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=40
scope.3.semanticHash=723b53ea03e1065b
scope.4.id=function:_guard_role
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=53
scope.4.semanticHash=9a7d62ce5219ddb8
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=51
scope.5.semanticHash=02dde704a852447e
scope.6.id=function:host_push.push
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=68
scope.6.semanticHash=b24e01ce3714e224
]]
