-- Import necessary modules
local assert = require("luassert")
local stub = require("luassert.stub")

-- System under test (main)
local sut = require("lua.projektgunnar.main")

-- Import necessary modules to be able to stub them
local utils = require("projektgunnar.utils")
local picker = require("projektgunnar.picker")
local async = require("projektgunnar.async")
local nugets = require("projektgunnar.nugets")

describe("main", function()
	local vim_input_stub
	local vim_notify_stub

	local utils_get_all_projects_in_solution_stub
	local picker_ask_user_for_choice_stub
	local async_handle_nugets_in_project
	local nugets_all_nugets_stub

	before_each(function()
		-- Stub `vim.fn.input` and `vim.notify`
		vim_input_stub = stub(vim.fn, "input")
		vim_notify_stub = stub(vim, "notify")

		-- Stubbing your own code
		utils_get_all_projects_in_solution_stub = stub(utils, "get_all_projects_in_solution")
		picker_ask_user_for_choice_stub = stub(picker, "ask_user_for_choice")
		async_handle_nugets_in_project = stub(async, "handle_nugets_in_project")
		nugets_all_nugets_stub = stub(nugets, "all_nugets")
	end)

	after_each(function()
		-- Revert stubs after each test to avoid pollution
		if vim_input_stub then
			vim_input_stub:revert()
		end
		if vim_notify_stub then
			vim_notify_stub:revert()
		end
		if utils_get_all_projects_in_solution_stub then
			utils_get_all_projects_in_solution_stub:revert()
		end
		if picker_ask_user_for_choice_stub then
			picker_ask_user_for_choice_stub:revert()
		end
	end)
	-- Start the test suite for `add_nuget_to_project`
	describe("add_nuget_to_project", function()
		it("should give an error if no NuGet is selected", function()
			-- Stub `input` to return an empty string
			vim_input_stub.returns("")

			-- Call the function in `main`
			sut.add_nuget_to_project()

			-- Assert the expected result
			assert.stub(vim_notify_stub).was_called_with("No nuget selected", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			-- Stub input to return a NuGet
			vim_input_stub.returns("Moq")

			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return an empty string to indicate no choice made
			picker_ask_user_for_choice_stub.returns()

			-- Call the function in main
			sut.add_nuget_to_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call async.handle_nugets_in_project with the correct arguments", function()
			-- Stub input to return a NuGet
			vim_input_stub.returns("Moq")

			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return a project
			picker_ask_user_for_choice_stub.returns("proj1")

			-- Call the function in main
			sut.add_nuget_to_project()

			-- Assert that async.handle_nugets_in_project was called with the correct arguments
			assert.stub(async_handle_nugets_in_project).was_called_with("Add", {
				{
					project = "proj1",
					command = "dotnet add proj1 package ",
					items = { "Moq" },
				},
			})
		end)
	end)

	describe("remove_nuget_from_project", function()
		it("should give an error if there are no projects in the solution", function()
			-- Stub utils.get_all_projects_in_solution to return an empty list
			utils_get_all_projects_in_solution_stub.returns({})

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No projects in solution", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return an empty string to indicate no choice made
			picker_ask_user_for_choice_stub.returns()

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give a warning if there are no NuGets in the project", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return a project
			picker_ask_user_for_choice_stub.returns("proj1")

			-- Stub nugets.all_nugets to return an empty list
			nugets_all_nugets_stub.returns({})

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No nugets in project proj1", vim.log.levels.WARN)
		end)

		it("should give a warning if no NuGets are selected for removal by the user", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			local call_count = 0

			-- Define custom behavior for the stub
			local my_stub = stub(picker, "ask_user_for_choice", function()
				call_count = call_count + 1
				if call_count == 1 then
					return "proj1"
				else
					return
				end
			end)

			-- Stub nugets.all_nugets to return a list of NuGets
			nugets_all_nugets_stub.returns({ "Moq", "NUnit" })

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No nuget chosen", vim.log.levels.WARN)

			my_stub:revert()
		end)
	end)
end)
