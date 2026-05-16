local handoff_message = require("swarmforge.handoff_message")

describe("swarmforge handoff_message", function()
  it("starts with the fixed greeting", function()
    local msg = handoff_message.build({
      source_role = "coder",
      target_role = "refactorer",
      branch = "swarmforge-coder",
      commit = "abc1234",
      summary = "已实现中文规格归一化",
    })

    assert.is_true(msg:sub(1, #"Review your rules.") == "Review your rules.")
  end)

  it("contains branch name", function()
    local msg = handoff_message.build({
      source_role = "specifier",
      target_role = "coder",
      branch = "main",
      commit = "deadbeef",
      summary = "中文 Gherkin 规格已接受",
    })

    assert.is_true(msg:find("main", 1, true) ~= nil)
  end)

  it("contains commit hash", function()
    local msg = handoff_message.build({
      source_role = "coder",
      target_role = "refactorer",
      branch = "swarmforge-coder",
      commit = "f3622d9",
      summary = "已实现中文规格归一化",
    })

    assert.is_true(msg:find("f3622d9", 1, true) ~= nil)
  end)

  it("contains change summary", function()
    local msg = handoff_message.build({
      source_role = "refactorer",
      target_role = "architect",
      branch = "swarmforge-refactorer",
      commit = "abc1234",
      summary = "已完成保行为重构",
    })

    assert.is_true(msg:find("已完成保行为重构", 1, true) ~= nil)
  end)

  it("returns the notify-agent script path", function()
    local script = handoff_message.notify_script_path()

    assert.is_true(script:find("swarmtools/notify%-agent%.sh") ~= nil)
  end)

  it("builds the full notify command", function()
    local cmd = handoff_message.notify_command({
      source_role = "coder",
      target_role = "refactorer",
      branch = "swarmforge-coder",
      commit = "abc1234",
      summary = "已实现中文规格归一化",
    })

    assert.is_true(cmd:find("notify%-agent%.sh") ~= nil)
    assert.is_true(cmd:find("refactorer", 1, true) ~= nil)
    assert.is_true(cmd:find("Review your rules.", 1, true) ~= nil)
  end)
end)
