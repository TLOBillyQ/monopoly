local lu = require("luaunit")
local status = require("acceptance4lua.mutator.status")

TestMutatorStatusFormat = {}

function TestMutatorStatusFormat:test_builds_snapshot_with_completed_work_including_skipped_mutations()
  local snapshot = status.snapshot(8, {
    killed = 2,
    survived = 1,
    errors = 1,
    skipped_scenarios = 3,
    skipped_mutations = 4,
  }, 0, "12s")

  lu.assertIs(snapshot.total, 8)
  lu.assertIs(snapshot.completed, 8)
  lu.assertIs(snapshot.running, 0)
  lu.assertIs(snapshot.elapsed, "12s")
  lu.assertIs(snapshot.killed, 2)
  lu.assertIs(snapshot.survived, 1)
  lu.assertIs(snapshot.errors, 1)
  lu.assertIs(snapshot.skipped_scenarios, 3)
  lu.assertIs(snapshot.skipped_mutations, 4)
end

function TestMutatorStatusFormat:test_normalizes_missing_numeric_fields_to_zero()
  local snapshot = status.snapshot(nil, nil, nil, nil)

  lu.assertIs(snapshot.total, 0)
  lu.assertIs(snapshot.completed, 0)
  lu.assertIs(snapshot.running, 0)
  lu.assertIs(snapshot.elapsed, "")
  lu.assertIs(snapshot.killed, 0)
  lu.assertIs(snapshot.survived, 0)
  lu.assertIs(snapshot.errors, 0)
  lu.assertIs(snapshot.skipped_scenarios, 0)
  lu.assertIs(snapshot.skipped_mutations, 0)
end

function TestMutatorStatusFormat:test_formats_status_lines_as_stable_key_value_tokens()
  local line = status.format_line({
    total = 8,
    completed = 8,
    running = 0,
    elapsed = "12s",
    killed = 2,
    survived = 1,
    errors = 1,
    skipped_scenarios = 3,
    skipped_mutations = 4,
  })

  lu.assertIs(
    line,
    "status elapsed=12s total=8 completed=8 running=0 killed=2 survived=1 errors=1 skipped_scenarios=3 skipped_mutations=4"
  )
end


return TestMutatorStatusFormat
