describe("merged stderr", function()
  for i = 1, 200 do
    it(string.format("case %d %s", i, string.rep("x", 40)), function()
      -- Match the original corruption: every third TAP line is followed by
      -- unbuffered stderr while stdout and stderr share one file handle.
      if i > 1 and (i - 1) % 3 == 0 then io.stderr:write("noise-from-stderr\n") end
      assert.is_true(true)
    end)
  end
end)
