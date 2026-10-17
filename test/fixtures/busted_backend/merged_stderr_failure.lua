describe("merged stderr failure", function()
  for i = 1, 200 do
    it(string.format("case %d %s", i, string.rep("x", 40)), function()
      if i > 1 and (i - 1) % 3 == 0 then io.stderr:write("noise-from-stderr\n") end
      assert.equals(
        string.format("expected %d %s", i, string.rep("y", 40)),
        string.format("actual %d %s", i, string.rep("z", 40)))
    end)
  end
end)
