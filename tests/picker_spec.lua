-- local assert = require("luassert")
--
-- -- import the luassert.mock module
-- local mock = require("luassert.mock")
-- local stub = require("luassert.stub")
--
-- describe("picker", function()
-- 	local mini_pick = require("mini.pick")
-- 	local picker = require("lua.projektgunnar.picker")
--
-- 	describe("ask_user_for_choice", function()
-- 		it("should return the choice", function()
-- 			-- mock("mini.pick", true)
-- 			local items = { "item1", "item2", "item3" }
-- 			stub(mini_pick, "ui_select").returns("item1")
--
-- 			local result = picker.ask_user_for_choice(items)
-- 			assert.are.same(result, "item1")
-- 		end)
-- 	end)
-- end)

-- Import necessary modules
local assert = require("luassert")
local stub = require("luassert.stub")

-- Describe your test suite
describe("picker", function()
	local mini_pick_ui_select_stub

	before_each(function()
		-- Stub the `ui_select` method from `mini.pick`
		local mini_pick = require("mini.pick")
		mini_pick_ui_select_stub = stub(mini_pick, "ui_select")
	end)

	after_each(function()
		-- Revert the stub after each test to avoid conflicts
		if mini_pick_ui_select_stub then
			mini_pick_ui_select_stub:revert()
		end
	end)

	it("should return the choice", function()
		-- Set the expected return value for the stub
		mini_pick_ui_select_stub.returns("item1")

		-- Test the function in `picker`
		local picker = require("lua.projektgunnar.picker")
		local items = { "item1", "item2", "item3" }

		-- Call the function that uses `ui_select`
		local result = picker.ask_user_for_choice(items)

		-- Assert the expected result
		assert.are.same("item1", result)
	end)
end)
