---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_swarm_root.lua") end
require("test.bootstrap").install_package_paths()

-- SwarmForge 项目根解析(packages.acceptance.swarm_root)的 spec。
--
-- 观测面:候选顺序(worktree 场景下 git --git-common-dir 的父目录必须排第一——APS 转发器
-- 只能落在 launcher 真正放 PATH 的那个根上)、相对 common dir 以 cwd 解析、
-- 「第一个真持有 .swarmforge/roles.tsv 的候选」这一选取语义,以及 roles 探针本身。
-- resolve() 的 git 两问是 IO 壳,其口径由 launcher 与 swarm_tool.sh 的既有约定约束,
-- 不在此重测。
local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local property = require("test.support.property")
local probe = require("test.support.aps_forwarder_probe")
local swarm_root = require("packages.acceptance.swarm_root")

-- 标记文件名是 launcher / swarm_tool.sh / provision 三方共用的约定,不是本模块的私有
-- 细节,所以这里按字面钉住:改这个名就得同时改三方。
local ROLES_MARKER = ".swarmforge/roles.tsv"

TestSwarmRoot = {}

function TestSwarmRoot:test_candidates_order_common_dir_parent_first()
  local candidates = swarm_root.swarm_root_candidates({
    git_common_dir = "/repo/.git",
    toplevel = "/repo/.worktrees/coder",
    cwd = "/repo/.worktrees/coder",
  })
  lu.assertEquals(candidates, { "/repo", "/repo/.worktrees/coder", "/repo/.worktrees/coder" })
end

function TestSwarmRoot:test_candidates_absolutize_a_relative_common_dir_against_cwd()
  local candidates = swarm_root.swarm_root_candidates({
    git_common_dir = ".git",
    toplevel = "/repo",
    cwd = "/repo",
  })
  lu.assertEquals(candidates, { "/repo", "/repo", "/repo" })
end

-- git 两问都可能没答案(不在仓里跑、git 不在 PATH):缺谁就少一条候选,cwd 恒兜底。
function TestSwarmRoot:test_candidates_degrade_to_the_cwd_when_git_gave_no_answer()
  lu.assertEquals(swarm_root.swarm_root_candidates({}), { "" })
  lu.assertEquals(swarm_root.swarm_root_candidates({ cwd = "/repo" }), { "/repo" })
  lu.assertEquals(swarm_root.swarm_root_candidates({ cwd = "C:\\repo\\wt" }), { "C:/repo/wt" },
    "反斜杠得先归一成 POSIX 分隔,否则整串被当成一个段名")
end

-- 退化输入必须单钉,不能只靠性质律兜:git 若报出 "/.git" 这种单段路径,parent_dir 折成
-- 空串,首位候选就为空。空串不是根,但它会走 join_path("" , marker) 变成**相对 cwd**
-- 的探测——真命中就把转发器落到相对路径上。select 的 dir ~= "" 守卫正是为它准备的。
function TestSwarmRoot:test_a_single_segment_common_dir_yields_an_empty_candidate_that_selection_skips()
  local candidates = swarm_root.swarm_root_candidates({
    git_common_dir = "/.git",
    toplevel = "",
    cwd = "/a/b",
  })
  lu.assertEquals(candidates, { "", "/a/b" })

  local probed = {}
  local chosen = swarm_root.select_swarm_root(candidates, function(dir)
    probed[#probed + 1] = dir
    return true
  end)
  lu.assertEquals(probed, { "/a/b" }, "空候选不得进探针")
  lu.assertIs(chosen, "/a/b")
end

function TestSwarmRoot:test_has_swarm_roles_only_answers_true_for_a_directory_holding_the_marker()
  probe.with_sandbox("roles_marker", function(root)
    lu.assertFalse(swarm_root.has_swarm_roles(root), "空目录不是 SwarmForge 根")

    local ok, err = fs_lib.ensure_dir(path_lib.join_path(root, ".swarmforge"))
    lu.assertTrue(ok, tostring(err))
    lu.assertFalse(swarm_root.has_swarm_roles(root), "光有 .swarmforge 目录不够,得有 roles.tsv")

    ok, err = fs_lib.write_file(path_lib.join_path(root, ROLES_MARKER), "role\tlane\n")
    lu.assertTrue(ok, tostring(err))
    lu.assertTrue(swarm_root.has_swarm_roles(root), "持 " .. ROLES_MARKER .. " 的目录就是 PATH 根")

    -- 不传探针就走这条文件谓词:这是 resolve() 与「launcher 放的根」之间唯一的连接点。
    lu.assertIs(swarm_root.select_swarm_root({ "/nope", root }), root,
      "缺省探针要在候选里挑真持有 roles.tsv 的那一个")
  end)
end

function TestSwarmRoot:test_select_picks_the_first_candidate_owning_the_roles_file()
  local chosen = swarm_root.select_swarm_root(
    { "/repo", "/repo/.worktrees/coder" },
    function(dir)
      return dir == "/repo"
    end)
  lu.assertIs(chosen, "/repo")

  local none = swarm_root.select_swarm_root({ "/elsewhere" }, function()
    return false
  end)
  lu.assertNil(none)
end

local _COMMON_DIRS_WITH_ANSWER = { "/repo/.git", ".git", "../.git", "nested/dir/.git", "/.git" }
local _SOURCES = {
  git_common_dir = { "/repo/.git", ".git", "../.git", "nested/dir/.git", "/.git", "" },
  toplevel = { "/repo/.worktrees/coder", "/repo", "worktrees/coder", "" },
  cwd = { "/repo/.worktrees/coder", "/repo", "C:\\repo\\wt", "/a/b" },
}

local function _generate_source(rng)
  return {
    git_common_dir = rng:pick(_SOURCES.git_common_dir),
    toplevel = rng:pick(_SOURCES.toplevel),
    cwd = rng:pick(_SOURCES.cwd),
  }
end

TestSwarmRootCandidateLaws = {}

-- 候选清单的形状就是这段演算的全部契约:一条 git 答案一条候选、顺序固定、末尾恒是 cwd。
function TestSwarmRootCandidateLaws:test_one_candidate_per_answer_with_the_cwd_always_last()
  property.for_all(_generate_source, function(source)
    local candidates = swarm_root.swarm_root_candidates(source)
    local expected_count = 1
      + (source.git_common_dir ~= "" and 1 or 0)
      + (source.toplevel ~= "" and 1 or 0)
    lu.assertEquals(#candidates, expected_count, property.describe(source))
    lu.assertEquals(candidates[#candidates], path_lib.normalize_path(source.cwd),
      "末位候选恒为归一化后的 cwd: " .. property.describe(source))
    for index, dir in ipairs(candidates) do
      lu.assertIsString(dir, "候选必须是字符串: " .. property.describe(source))
      -- 空串只可能出现在首位、且只可能来自单段 common dir(见上面的字面例子);
      -- 其余位置为空就是真漂移。
      lu.assertTrue(dir ~= "" or (index == 1 and source.git_common_dir ~= ""),
        "第 " .. index .. " 位候选不该为空: " .. property.describe(source))
    end
    lu.assertEquals(swarm_root.swarm_root_candidates(source), candidates,
      "纯演算不得读环境:同输入两次结果必须相同")
  end, { cases = 120 })
end

-- 只在「git 真报了 common dir」的输入面上演算:没有 common dir 时首位本来就是
-- toplevel,拿它做随机扰动会让一半用例空转,绿得没有意义。
local function _generate_source_with_common_dir(rng)
  local source = _generate_source(rng)
  source.git_common_dir = rng:pick(_COMMON_DIRS_WITH_ANSWER)
  return source
end

function TestSwarmRootCandidateLaws:test_git_common_dir_keeps_first_say_over_the_worktree_toplevel()
  property.for_all(_generate_source_with_common_dir, function(source, rng)
    local first = swarm_root.swarm_root_candidates(source)[1]
    for _ = 1, 3 do
      local alternative = { cwd = source.cwd, git_common_dir = source.git_common_dir }
      alternative.toplevel = rng:pick(_SOURCES.toplevel)
      lu.assertEquals(swarm_root.swarm_root_candidates(alternative)[1], first,
        "换掉本 worktree 顶不许动首位候选: " .. property.describe(alternative))
    end
  end, { cases = 40 })
end

local _DIRS = { "/repo", "/repo/.worktrees/coder", "/elsewhere", "" }

local function _generate_selection_case(rng)
  local candidates = {}
  local holders = {}
  for _ = 1, rng:int(0, 4) do
    local dir = rng:pick(_DIRS)
    candidates[#candidates + 1] = dir
    if dir ~= "" and rng:bool() then
      holders[dir] = true
    end
  end
  return { candidates = candidates, holders = holders }
end

TestSwarmRootSelectionLaws = {}

-- 选取语义:第一个持有标记的候选即根,命中即停(不为一一探完而多碰文件系统),空串
-- 候选根本不进探针;谁都不持有就没有可供给的根。
function TestSwarmRootSelectionLaws:test_earliest_holder_wins_and_the_probe_short_circuits()
  property.for_all(_generate_selection_case, function(case)
    local expected = nil
    local expected_probes = {}
    for _, dir in ipairs(case.candidates) do
      if dir ~= "" then
        expected_probes[#expected_probes + 1] = dir
        if expected == nil and case.holders[dir] then
          expected = dir
          break
        end
      end
    end

    local probed = {}
    local chosen = swarm_root.select_swarm_root(case.candidates, function(dir)
      probed[#probed + 1] = dir
      return case.holders[dir] == true
    end)
    lu.assertIs(chosen, expected, "选取不符: " .. property.describe(case.candidates))
    lu.assertEquals(probed, expected_probes,
      "探针调用序列不符(顺序或提前停止): " .. property.describe(case.candidates))
  end, { cases = 200 })
end
