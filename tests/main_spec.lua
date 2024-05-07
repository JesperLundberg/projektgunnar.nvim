local assert = require("luassert")

-- import the luassert.mock module
local mock = require("luassert.mock")
local stub = require("luassert.stub")

describe("main", function()
	local main = require("lua.projektgunnar.main")

	local async = require("lua.projektgunnar.async")
	local utils = require("lua.projektgunnar.utils")
	local picker = require("lua.projektgunnar.picker")

	describe("add_nuget_to_project", function()
		it("should give an error if no nuget is selected", function()
			local vim = mock(vim, true)

			vim.fn.input().returns("")

			-- Call the function in `main`
			main.add_nuget_to_project()

			-- Assert the expected result
			assert.stub(vim.notify).was_called_with("No nuget selected", vim.log.levels.ERROR)
		end)

		-- 	it("should call async with the correct command", function()
		-- 		-- Stub the `input` method from `vim.fn`
		-- 		stub(vim.fn, "input").returns("nuget1")
		--
		-- 		-- Stub the `get_all_projects_in_solution` method from `utils`
		-- 		stub(utils, "get_all_projects_in_solution").returns({
		-- 			"project1",
		-- 			"project2",
		-- 			"project3",
		-- 		})
		--
		-- 		-- Stub the `ask_user_for_choice` method from `picker`
		-- 		stub(picker, "ask_user_for_choice").returns("project1")
		--
		-- 		print("before mock in test file")
		--
		-- 		-- Mock the `handle_nugets_in_project` method from `async`
		-- 		mock(async, true)
		--
		-- 		-- Call the function in `main`
		-- 		main.add_nuget_to_project()
		--
		-- 		-- Assert the expected result
		-- 		assert.mocked(require("lua.projektgunnar.async")).was_called(1)
		-- 		assert.mocked(require("lua.projektgunnar.async")).was_called_with("Add", {
		-- 			[1] = { project = "project1", command = "dotnet add project1 package ", items = { "nuget1" } },
		-- 		})
		-- 	end)
	end)
end)
