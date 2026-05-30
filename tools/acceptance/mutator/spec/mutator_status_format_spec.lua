local status = require("acceptance4lua.mutator.status")

describe("acceptance4lua.mutator.status", function()
  it("builds a snapshot with completed work including skipped mutations", function()
    local snapshot = status.snapshot(8, {
      killed = 2,
      survived = 1,
      errors = 1,
      skipped_scenarios = 3,
      skipped_mutations = 4,
    }, 0, "30s")

    assert.are.equal(8, snapshot.total)
    assert.are.equal(8, snapshot.completed)
    assert.are.equal(0, snapshot.running)
    assert.are.equal("30s", snapshot.interval)
    assert.are.equal(2, snapshot.killed)
    assert.are.equal(1, snapshot.survived)
    assert.are.equal(1, snapshot.errors)
    assert.are.equal(3, snapshot.skipped_scenarios)
    assert.are.equal(4, snapshot.skipped_mutations)
  end)

  it("normalizes missing numeric fields to zero", function()
    local snapshot = status.snapshot(nil, nil, nil, nil)

    assert.are.equal(0, snapshot.total)
    assert.are.equal(0, snapshot.completed)
    assert.are.equal(0, snapshot.running)
    assert.are.equal("", snapshot.interval)
    assert.are.equal(0, snapshot.killed)
    assert.are.equal(0, snapshot.survived)
    assert.are.equal(0, snapshot.errors)
    assert.are.equal(0, snapshot.skipped_scenarios)
    assert.are.equal(0, snapshot.skipped_mutations)
  end)

  it("formats status lines as stable key-value tokens", function()
    local line = status.format_line({
      total = 8,
      completed = 8,
      running = 0,
      interval = "30s",
      killed = 2,
      survived = 1,
      errors = 1,
      skipped_scenarios = 3,
      skipped_mutations = 4,
    })

    assert.are.equal(
      "status total=8 completed=8 running=0 interval=30s killed=2 survived=1 errors=1 skipped_scenarios=3 skipped_mutations=4",
      line
    )
  end)
end)
