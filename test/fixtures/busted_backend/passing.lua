describe("real busted execution", function()
  for _, example in ipairs({ { 2, 3, 5 }, { 4, 5, 9 } }) do
    it("adds " .. example[1] .. " and " .. example[2], function()
      assert.equals(example[3], example[1] + example[2])
    end)
  end
end)
