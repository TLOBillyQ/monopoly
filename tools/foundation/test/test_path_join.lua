---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_path_join.lua") end
require("test.bootstrap").install_package_paths()

-- join_path 的行为规约(issue #211)。
--
-- 缺陷形态:join_path 只接两个形参,第三段起被静默丢弃。调用方写
-- join_path(root, "tmp", "lua54-shim") 读起来是三段路径,实得两段,且不报错——
-- 「静默丢参」这个失败模式本身才是缺陷,不是某一处调用点写错。
--
-- 本规约把 join_path 钉成变参折叠:任意段数逐段左折,2 段语义原样保留。
-- 纯字符串演算,不碰文件系统(见 tools/foundation/path.lua 顶部的边界声明),
-- 所以这里不需要临时目录也不需要替身。
local lu = require("luaunit")
local path = require("foundation.path")
local property = require("test.support.property")

TestPathJoinSegmentCount = {}

function TestPathJoinSegmentCount:test_joins_two_segments()
  lu.assertIs(path.join_path("root", "tmp"), "root/tmp")
end

-- #211 的哑弹:这一条在修复前为红。
function TestPathJoinSegmentCount:test_joins_three_segments_instead_of_dropping_the_third()
  lu.assertIs(path.join_path("root", "tmp", "lua54-shim"), "root/tmp/lua54-shim")
end

function TestPathJoinSegmentCount:test_joins_an_arbitrary_number_of_segments()
  lu.assertIs(path.join_path("root", "a", "b", "c", "d"), "root/a/b/c/d")
end

function TestPathJoinSegmentCount:test_returns_the_sole_segment_when_only_one_is_given()
  lu.assertIs(path.join_path("root"), "root")
end

function TestPathJoinSegmentCount:test_returns_an_empty_string_when_no_segment_is_given()
  lu.assertIs(path.join_path(), "")
end

TestPathJoinEmptyAndNilSegments = {}

function TestPathJoinEmptyAndNilSegments:test_skips_an_empty_leading_segment()
  lu.assertIs(path.join_path("", "tmp", "lua54-shim"), "tmp/lua54-shim")
end

function TestPathJoinEmptyAndNilSegments:test_skips_an_empty_middle_segment()
  lu.assertIs(path.join_path("root", "", "lua54-shim"), "root/lua54-shim")
end

function TestPathJoinEmptyAndNilSegments:test_skips_an_empty_trailing_segment()
  lu.assertIs(path.join_path("root", "tmp", ""), "root/tmp")
end

-- nil 容忍不是修辞:2 段形态下 normalize_path(nil) 已折成空串,变参形态必须
-- 保持同一口径。这条同时钉死实现不能用 ipairs({...}) 收集变参——nil 洞会让
-- ipairs 提前截断,把 nil 之后的段一并吞掉,等于换个马甲重演本工单的缺陷。
function TestPathJoinEmptyAndNilSegments:test_treats_a_nil_segment_as_empty_and_keeps_the_segments_after_it()
  lu.assertIs(path.join_path("root", nil, "lua54-shim"), "root/lua54-shim")
end

function TestPathJoinEmptyAndNilSegments:test_treats_a_nil_leading_segment_as_empty()
  lu.assertIs(path.join_path(nil, "tmp", "lua54-shim"), "tmp/lua54-shim")
end

TestPathJoinSeparatorNormalization = {}

function TestPathJoinSeparatorNormalization:test_collapses_redundant_separators_between_segments()
  lu.assertIs(path.join_path("root/", "/tmp/", "/lua54-shim"), "root/tmp/lua54-shim")
end

function TestPathJoinSeparatorNormalization:test_normalizes_backslashes_across_every_segment()
  lu.assertIs(path.join_path("root\\a", "b\\c"), "root/a/b/c")
end

function TestPathJoinSeparatorNormalization:test_preserves_an_absolute_base_across_multiple_segments()
  lu.assertIs(path.join_path("/root", "tmp", "lua54-shim"), "/root/tmp/lua54-shim")
end

function TestPathJoinSeparatorNormalization:test_preserves_a_windows_drive_base_across_multiple_segments()
  lu.assertIs(path.join_path("C:/root", "tmp", "lua54-shim"), "C:/root/tmp/lua54-shim")
end

-- 上面的例子钉的是「某几组输入应得什么」;这里钉的是折叠本身的定律,不依赖具体段值。
--
-- 结合律是「逐段左折」这个说法的全部含义:n 段一次折,必须等于两两迭代折。它同时
-- 是本工单的反向保险——静默丢参之所以能潜伏,正因为没有任何规约把 n 段形态与 2 段
-- 形态绑在一起,调用方改写段数时无从察觉。段池里塞进空段、nil 段、绝对段、盘符段、
-- 首尾斜杠与反斜杠,因为这些正是折叠里唯一带分支的地方。
local SEGMENT_POOL = { "root", "a", "b", "", "/abs", "C:/drive", "x/", "/y", "p\\q", "NIL" }

-- nil 是合法段,但表里存 nil 会留洞;用哨兵存、取用时还原,并靠 count 保住洞的位置。
local function _generate_segments(rng)
  local count = rng:int(1, 5)
  local values = {}
  for index = 1, count do
    values[index] = rng:pick(SEGMENT_POOL)
  end
  return { count = count, values = values }
end

local function _unpack_segments(case)
  local args = {}
  for index = 1, case.count do
    local value = case.values[index]
    args[index] = (value ~= "NIL") and value or nil
  end
  return table.unpack(args, 1, case.count)
end

TestPathJoinFoldingLaws = {}

function TestPathJoinFoldingLaws:test_is_associative_folding_n_segments_at_once_equals_folding_them_pairwise()
  property.for_all(_generate_segments, function(case)
    local at_once = path.join_path(_unpack_segments(case))

    local pairwise = path.join_path(case.values[1] ~= "NIL" and case.values[1] or nil)
    for index = 2, case.count do
      local value = case.values[index]
      pairwise = path.join_path(pairwise, (value ~= "NIL") and value or nil)
    end

    lu.assertIs(at_once, pairwise)
  end)
end

function TestPathJoinFoldingLaws:test_agrees_with_normalize_path_on_a_single_segment()
  property.for_all(_generate_segments, function(case)
    local value = case.values[1]
    local segment = (value ~= "NIL") and value or nil
    lu.assertIs(path.join_path(segment), path.normalize_path(segment))
  end)
end

function TestPathJoinFoldingLaws:test_is_idempotent_re_joining_an_already_joined_path_changes_nothing()
  property.for_all(_generate_segments, function(case)
    local joined = path.join_path(_unpack_segments(case))
    lu.assertIs(path.join_path(joined), joined)
  end)
end


return TestPathJoinSegmentCount
