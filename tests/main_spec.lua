-- Import necessary modules
local assert = require("luassert")
local stub = require("luassert.stub")
local mock = require("luassert.mock")

describe("main", function()
	-- Import the main module and other necessary modules
	local main = require("lua.projektgunnar.main")

	local vim_input_stub
	local vim_notify_stub

	local utils_get_all_projects_in_solution_stub

	before_each(function()
		-- Stub `vim.fn.input` and `vim.notify`
		vim_input_stub = stub(vim.fn, "input")
		vim_notify_stub = stub(vim, "notify")

		-- Stub `utils.get_all_projects_in_solution` to return a list of projects
		utils_get_all_projects_in_solution_stub =
			stub(require("lua.projektgunnar.utils"), "get_all_projects_in_solution")
		utils_ask_user_for_choice_stub = stub(require("lua.projektgunnar.utils"), "ask_user_for_choice")
	end)

	after_each(function()
		-- Revert the stubs to ensure a clean environment
		if vim_input_stub then
			vim_input_stub:revert()
		end
		if vim_notify_stub then
			vim_notify_stub:revert()
		end
	end)
	-- Start the test suite for `add_nuget_to_project`
	describe("add_nuget_to_project", function()
		it("should give an error if no NuGet is selected", function()
			-- Stub `input` to return an empty string
			vim_input_stub.returns("")

			-- Call the function in `main`
			main.add_nuget_to_project()

			-- Assert the expected result
			assert.stub(vim_notify_stub).was_called_with("No nuget selected", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			-- Stub `input` to return a NuGet
			vim_input_stub.returns("NuGet")

			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			utils_ask_user_for_choice_stub.returns("")

			-- Call the function in `main`
			main.add_nuget_to_project()

			-- Assert the expected result
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)
	end)
end)
