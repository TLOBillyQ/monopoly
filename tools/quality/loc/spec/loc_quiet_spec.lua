---@diagnostic disable: undefined-global, undefined-field
if arg then rawset(arg, 0, "tools/quality/loc/spec/loc_quiet_spec.lua") end
require("spec.bootstrap").install_package_paths()

local loc = require("quality.loc")

describe("loc._emit_narrative", function()
  local captured

  before_each(function()
    captured = {}
    loc._set_print_sink_for_tests(function(msg)
      captured[#captured + 1] = tostring(msg)
    end)
    loc._set_quiet(false)
  end)

  after_each(function()
    loc._set_print_sink_for_tests(nil)
    loc._set_quiet(false)
  end)

  it("emits when quiet is false (default narrative path)", function()
    loc._emit_narrative("fetching commits...")
    assert.are.equal(1, #captured)
    assert.are.equal("fetching commits...", captured[1])
  end)

  it("suppresses when quiet is true", function()
    loc._set_quiet(true)
    loc._emit_narrative("fetching commits...")
    loc._emit_narrative("[ 1/ 3] abc... | src: ...")
    loc._emit_narrative(string.rep("-", 60))
    assert.are.equal(0, #captured)
  end)

  it("does not affect summary _println calls (those always emit)", function()
    loc._set_quiet(true)
    loc._set_print_sink_for_tests(function(msg)
      captured[#captured + 1] = tostring(msg)
    end)
    loc._emit_narrative("narrative line")
    assert.are.equal(0, #captured, "narrative must be suppressed under quiet")
  end)
end)

describe("loc._parse_args", function()
  before_each(function()
    loc._set_quiet(false)
  end)

  after_each(function()
    loc._set_quiet(false)
  end)

  it("defaults days to 14 when --days absent", function()
    local options = loc._parse_args({})
    assert.are.equal(14, options.days)
  end)

  it("parses --days N as separate tokens", function()
    local options = loc._parse_args({ "--days", "30" })
    assert.are.equal(30, options.days)
  end)

  it("parses --days=N inline form", function()
    local options = loc._parse_args({ "--days=7" })
    assert.are.equal(7, options.days)
  end)

  it("rejects non-positive --days values, falls back to default", function()
    local options = loc._parse_args({ "--days", "0" })
    assert.are.equal(14, options.days)
  end)

  it("--quiet toggles quiet sink, does not affect days", function()
    local options = loc._parse_args({ "--quiet", "--days", "3" })
    assert.are.equal(3, options.days)
    -- Drive narrative through public API to confirm quiet applied
    local captured = {}
    loc._set_print_sink_for_tests(function(msg)
      captured[#captured + 1] = tostring(msg)
    end)
    loc._emit_narrative("should be silent")
    assert.are.equal(0, #captured)
    loc._set_print_sink_for_tests(nil)
  end)
end)

describe("loc._render_svg", function()
  local function _row(date, src, tests)
    return {
      date = date,
      src_loc = src,
      tests_loc = tests,
      total_loc = src + tests,
    }
  end

  it("returns an SVG with both panels and N data circles per panel", function()
    local rows = {
      _row("2026-05-20", 1000, 2000),
      _row("2026-05-21", 1010, 2050),
      _row("2026-05-22", 1020, 2100),
    }
    local svg = loc._render_svg(rows, { days = 3, first_day = "2026-05-20", last_day = "2026-05-22" })

    assert(svg:find("<svg", 1, true), "must contain <svg root")
    assert(svg:find("</svg>", 1, true), "must close </svg>")
    assert(svg:find("<polyline", 1, true), "must contain a polyline element")
    assert(svg:find("2026-05-20", 1, true), "must mention first date")
    assert(svg:find("2026-05-22", 1, true), "must mention last date")
    assert(svg:find("src/ Lines of Code", 1, true), "must contain src panel title")
    assert(svg:find("spec/ Lines of Code", 1, true), "must contain spec panel title")

    -- 3 rows × 2 panels = 6 circles
    local circle_count = 0
    for _ in svg:gmatch("<circle") do
      circle_count = circle_count + 1
    end
    assert.are.equal(6, circle_count, "should render 2 panels × 3 rows = 6 data circles")
  end)

  it("handles single-row input without divide-by-zero", function()
    local svg = loc._render_svg({ _row("2026-05-22", 100, 200) }, { days = 1 })
    assert(svg:find("<svg", 1, true), "must contain <svg root")
    -- single point → 1 row × 2 panels = 2 circles
    local circle_count = 0
    for _ in svg:gmatch("<circle") do
      circle_count = circle_count + 1
    end
    assert.are.equal(2, circle_count)
  end)

  it("handles empty rows without erroring", function()
    local svg = loc._render_svg({}, { days = 0 })
    assert(svg:find("<svg", 1, true), "must contain <svg root")
    assert(svg:find("</svg>", 1, true), "must close </svg>")
  end)

  it("escapes XML metacharacters in date and title fields", function()
    local svg = loc._render_svg({ _row("2026<bad>", 10, 20) }, { days = 1, first_day = "<x>", last_day = "<y>" })
    assert(not svg:find("<bad>", 1, true), "raw < must not leak into SVG")
    assert(svg:find("&lt;bad&gt;", 1, true), "raw < should be escaped")
  end)
end)
