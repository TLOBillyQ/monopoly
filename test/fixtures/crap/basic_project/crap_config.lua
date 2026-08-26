-- #361 P1 fixture 配置:collect/report 契约用例对这个 3 文件项目跑,毫秒级完成。
-- adapter 落固定 luacov 报告;report 产物写系统 tmp(绝对路径,crap4lua 原样采纳),
-- 不在 fixture 目录留生成物。
local tmp_dir = (os.getenv("TMPDIR") or "/tmp"):gsub("/+$", "")

return {
  project_name = "CrapFixture",
  project_root = ".",
  source_roots = { "src" },
  coverage = {
    adapter = "adapter.lua",
    report = tmp_dir .. "/luacov.crap_fixture.report.out",
  },
}
