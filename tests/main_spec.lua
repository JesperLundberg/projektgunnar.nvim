-- Import necessary modules
local assert = require("luassert")
local stub = require("luassert.stub")

-- System under test (main)
local sut = require("projektgunnar.main")

-- Import necessary modules to be able to stub them
local utils = require("projektgunnar.utils")
local picker = require("projektgunnar.picker")
local dotnet_jobs = require("projektgunnar.dotnet_jobs")
local nugets = require("projektgunnar.nugets")
local async_ = require("projektgunnar.async")

describe("main", function()
	-- Define stub variables
	local vim_notify_stub

	local utils_get_all_projects_in_solution_stub
	local utils_get_all_projects_in_solution_folder_not_in_solution
	local utils_get_project_references_stub
	local picker_ask_user_for_choice_stub
	local async_handle_nugets_in_project
	local async_handle_project_reference
	local async_add_project_to_solution
	local async_stub
	local nugets_all_nugets_stub
	local nugets_outdated_nugets_stub

	--- Test-helper
	--- @param seq table
	local function stub_picker_choices(seq)
		picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
			cb(table.remove(seq, 1))
		end)
	end

	before_each(function()
		-- Stub `vim.fn.input` and `vim.notify`
		vim_notify_stub = stub(vim, "notify")

		-- Make async.run synchronous for *all* tests
		async_stub = stub(async_, "run")
		async_stub.invokes(function(fn)
			fn()
		end)

		-- Stubbing projektgunnar methods
		utils_get_all_projects_in_solution_stub = stub(utils, "get_all_projects_in_solution")
		utils_get_all_projects_in_solution_folder_not_in_solution =
			stub(utils, "get_all_projects_in_solution_folder_not_in_solution")
		utils_get_project_references_stub = stub(utils, "get_project_references")
		picker_ask_user_for_choice_stub = stub(picker, "ask_user_for_choice")
		async_handle_nugets_in_project = stub(dotnet_jobs, "handle_nugets_in_project")
		async_handle_project_reference = stub(dotnet_jobs, "handle_project_reference")
		async_add_project_to_solution = stub(dotnet_jobs, "add_project_to_solution")
		nugets_all_nugets_stub = stub(nugets, "all_nugets")
		nugets_outdated_nugets_stub = stub(nugets, "outdated_nugets")
	end)

	after_each(function()
		-- Revert stubs after each test to avoid pollution
		if vim_notify_stub then
			vim_notify_stub:revert()
		end
		if utils_get_all_projects_in_solution_stub then
			utils_get_all_projects_in_solution_stub:revert()
		end
		if utils_get_all_projects_in_solution_folder_not_in_solution then
			utils_get_all_projects_in_solution_folder_not_in_solution:revert()
		end
		if picker_ask_user_for_choice_stub then
			picker_ask_user_for_choice_stub:revert()
		end
		if async_handle_nugets_in_project then
			async_handle_nugets_in_project:revert()
		end
		if async_handle_project_reference then
			async_handle_project_reference:revert()
		end
		if async_add_project_to_solution then
			async_add_project_to_solution:revert()
		end
		if async_stub then
			async_stub:revert()
		end
		if nugets_all_nugets_stub then
			nugets_all_nugets_stub:revert()
		end
		if nugets_outdated_nugets_stub then
			nugets_outdated_nugets_stub:revert()
		end
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
			stub_picker_choices({})

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give a warning if there are no NuGets in the project", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return a project
			stub_picker_choices({ "proj1" })

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

			stub_picker_choices({ "proj1", nil })

			-- Stub nugets.all_nugets to return a list of NuGets
			nugets_all_nugets_stub.returns({ "Moq", "NUnit" })

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No nuget chosen", vim.log.levels.WARN)
		end)

		it("should call async.handle_nugets_in_project with the correct arguments", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			stub_picker_choices({ "proj1", "Moq" })

			-- Stub nugets.all_nugets to return a list of NuGets
			nugets_all_nugets_stub.returns({ "Moq", "NUnit" })

			-- Call the function in main
			sut.remove_nuget_from_project()

			-- Assert that async.handle_nugets_in_project was called with the correct arguments
			assert.stub(async_handle_nugets_in_project).was_called_with("Remove", {
				{
					argv = { "dotnet", "remove", "proj1", "package" },
					items = { "Moq" },
				},
			})
		end)
	end)

	describe("update_nugets_in_project", function()
		it("should give an error if no project is selected", function()
			-- Stub utils.get_all_projects_in_solution to return project
			utils_get_all_projects_in_solution_stub.returns({ "proj1" })

			-- Simulate no project chosen
			stub_picker_choices({})

			-- Call the function in main
			sut.update_nugets_in_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give a warning if there are no NuGets in the project", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return a project
			stub_picker_choices({ "proj1" })

			-- Stub nugets.outdated_nugets to return an empty list
			nugets_outdated_nugets_stub.returns({})

			-- Call the function in main
			sut.update_nugets_in_project()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No outdated nugets in project proj1", vim.log.levels.WARN)
		end)

		it("should call async.handle_nugets_in_project with the correct arguments", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Define custom behavior for the stub
			stub_picker_choices({ "proj1" })

			-- Stub nugets.outdated_nugets to return an a list
			nugets_outdated_nugets_stub.returns({ "Moq", "NUnit" }, nil)

			-- Call the function in main
			sut.update_nugets_in_project()

			-- Assert that async.handle_nugets_in_project was called with the correct arguments
			assert.stub(async_handle_nugets_in_project).was_called_with("Update", {
				{
					argv = { "dotnet", "add", "proj1", "package" }, -- Updating and adding a NuGet is the same command
					items = { "Moq", "NUnit" },
				},
			})
		end)
	end)

	describe("add_project_reference", function()
		it("should give an error if no projects exist in solution", function()
			-- Stub utils.get_all_projects_in_solution to return an empty list
			utils_get_all_projects_in_solution_stub.returns({})

			-- Call the function in main
			sut.add_project_reference()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No projects in solution", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return an empty string to indicate no choice made
			stub_picker_choices({})

			-- Call the function in main
			sut.add_project_reference()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give an error if no project to add to is selected", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Return 'proj1' to first call and no choice to second call
			stub_picker_choices({ "proj1", nil })

			-- Call the function in main
			sut.add_project_reference()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call async.handle_project_reference with the correct arguments", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Return 'proj1' to first call and 'proj2' to second call
			stub_picker_choices({ "proj1", "proj2" })

			-- Call the function in main
			sut.add_project_reference()

			-- Assert that async.handle_nugets_in_project was called with the correct arguments
			assert.stub(async_handle_project_reference).was_called_with("add", "proj1", "proj2")
		end)
	end)

	describe("remove_project_reference", function()
		it("should give an error if no projects exist in solution", function()
			-- Stub utils.get_all_projects_in_solution to return an empty list
			utils_get_all_projects_in_solution_stub.returns({})

			-- Call the function in main
			sut.remove_project_reference()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No projects in solution", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub picker.ask_user_for_choice to return an empty string to indicate no choice made
			stub_picker_choices({ nil })

			-- Call the function in main
			sut.remove_project_reference()

			-- Assert that vim.notify was called with the expected arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call async.handle_project_reference with the correct arguments", function()
			-- Stub utils.get_all_projects_in_solution to return a list of projects
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })

			-- Stub utils.get_project_references to return the references of chosen project
			utils_get_project_references_stub.returns({ "proj2" })

			-- Stub the choices of 'proj1' (source) and 'proj2' (reference to remove)
			stub_picker_choices({ "proj1", "proj2" })

			sut.remove_project_reference()

			-- Assert
			assert.stub(async_handle_project_reference).was_called_with("remove", "proj1", "proj2")
		end)
	end)

	describe("add_project_to_solution", function()
		it("should give an error if no project is selected", function()
			-- Stub `get_all_projects_in_solution_folder_not_in_solution` to return an empty list
			-- Stub `get_all_projects_in_solution` to return a list
			utils_get_all_projects_in_solution_folder_not_in_solution.returns({ "proj1" })
			utils_get_all_projects_in_solution_stub.returns({})
			stub_picker_choices({ nil })

			-- Call the function in `main`
			sut.add_project_to_solution()

			-- Assert the expected result
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is chosen to be added to solution", function()
			-- Stub `get_all_projects_in_solution_folder_not_in_solution` to return a list
			utils_get_all_projects_in_solution_folder_not_in_solution.returns({ "proj1" })
			-- Stub `get_all_projects_in_solution` to return a list that does not contain the above project
			utils_get_all_projects_in_solution_stub.returns({ "proj2", "proj3" })
			-- Stub `picker.ask_user_for_choice` to return an empty string
			stub_picker_choices({ nil })

			-- Call the function in `main`
			sut.add_project_to_solution()

			-- Assert that async.handle_nugets_in_project was called with the correct arguments
			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call async.handle_project_reference with the correct arguments", function()
			-- Stub `get_all_projects_in_solution_folder_not_in_solution` to return a list
			utils_get_all_projects_in_solution_folder_not_in_solution.returns({ "proj1" })
			-- Stub `get_all_projects_in_solution` to return a list that does not contain the above project
			utils_get_all_projects_in_solution_stub.returns({ "proj2", "proj3" })
			-- Stub `picker.ask_user_for_choice` to return a project
			stub_picker_choices({ "proj1" })

			-- Call the function in `main`
			sut.add_project_to_solution()

			-- Assert that async.handle_nugets_in_project was called with the correct arguments
			assert.stub(async_add_project_to_solution).was_called_with("proj1")
		end)
	end)
end)
