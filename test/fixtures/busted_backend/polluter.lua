local shared = require("test.fixtures.busted_backend.shared")
describe("cross file polluter", function()
  after_each(function() shared.logger.warn = shared.warn end)
  it("patches the shared module", function()
    shared.logger.warn = function() end
    assert.equals(shared.logger, require("src.foundation.log"))
    assert.is_not.equal(shared.warn, shared.logger.warn)
  end)
end)
