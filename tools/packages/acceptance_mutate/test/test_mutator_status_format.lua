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


-- Public argument validation returns before any filesystem or worker operation.
local mutator = require("acceptance4lua.mutator")

function TestMutatorStatusFormat:test_rejects_an_unknown_level_value_before_touching_the_filesystem()
  local report, err = mutator.run({
    feature = "/nonexistent/path/intentionally-bad.feature",
    work_dir = "/tmp/will-not-be-created",
    level = "nonsense",
  })
  lu.assertNil(report)
  lu.assertNotNil(err)
  lu.assertEvalToTrue(tostring(err):match("invalid level"))
end

function TestMutatorStatusFormat:test_rejects_non_string_level_values()
  local report, err = mutator.run({
    feature = "/dev/null",
    work_dir = "/tmp",
    level = 42,
  })
  lu.assertNil(report)
  lu.assertEvalToTrue(tostring(err):match("invalid level"))
end

return TestMutatorStatusFormat
