local assert = require("luassert")
local stub = require("luassert.stub")

local sut = require("projektgunnar.main")

local utils = require("projektgunnar.utils")
local picker = require("projektgunnar.picker")
local dotnet_jobs = require("projektgunnar.dotnet_jobs")
local nugets = require("projektgunnar.nugets")
local async_ = require("projektgunnar.async")
local solution = require("projektgunnar.solution")

describe("main", function()
	-- Stubs
	local vim_notify_stub
	local vim_schedule_stub

	local async_run_stub
	local solution_resolve_stub

	local utils_get_all_projects_in_solution_stub
	local utils_get_project_references_stub
	local utils_get_all_project_files_stub
	local utils_get_nuget_config_file_stub

	local picker_ask_user_for_choice_stub

	local dotnet_handle_nugets_in_project_stub
	local dotnet_handle_project_reference_stub
	local dotnet_add_project_to_solution_stub

	local nugets_all_nugets_stub
	local nugets_outdated_nugets_stub

	-- Helper to simulate sequential picker choices (including nil for cancel).
	local function stub_picker_choices(seq)
		picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
			cb(table.remove(seq, 1))
		end)
	end

	before_each(function()
		-- Stub notifications and make scheduled callbacks run immediately.
		vim_notify_stub = stub(vim, "notify")
		vim_schedule_stub = stub(vim, "schedule")
		vim_schedule_stub.invokes(function(fn)
			fn()
		end)

		-- Make async.run synchronous for all tests.
		async_run_stub = stub(async_, "run")
		async_run_stub.invokes(function(fn)
			fn()
		end)

		-- Always resolve a fake solution unless a test overrides it.
		solution_resolve_stub = stub(solution, "resolve")
		solution_resolve_stub.invokes(function(cb)
			cb("/fake/path/to/solution.sln")
		end)

		-- Stub utils functions used by main.
		utils_get_all_projects_in_solution_stub = stub(utils, "get_all_projects_in_solution")
		utils_get_project_references_stub = stub(utils, "get_project_references")
		utils_get_all_project_files_stub = stub(utils, "get_all_project_files")
		utils_get_nuget_config_file_stub = stub(utils, "get_nuget_config_file")
		utils_get_nuget_config_file_stub.returns("/fake/path/to/nuget.config")

		-- Stub picker and dotnet jobs.
		picker_ask_user_for_choice_stub = stub(picker, "ask_user_for_choice")

		dotnet_handle_nugets_in_project_stub = stub(dotnet_jobs, "handle_nugets_in_project")
		dotnet_handle_project_reference_stub = stub(dotnet_jobs, "handle_project_reference")
		dotnet_add_project_to_solution_stub = stub(dotnet_jobs, "add_project_to_solution")

		-- Stub nuget queries.
		nugets_all_nugets_stub = stub(nugets, "all_nugets")
		nugets_outdated_nugets_stub = stub(nugets, "outdated_nugets")
	end)

	after_each(function()
		if vim_notify_stub then
			vim_notify_stub:revert()
		end
		if vim_schedule_stub then
			vim_schedule_stub:revert()
		end

		if async_run_stub then
			async_run_stub:revert()
		end
		if solution_resolve_stub then
			solution_resolve_stub:revert()
		end

		if utils_get_all_projects_in_solution_stub then
			utils_get_all_projects_in_solution_stub:revert()
		end
		if utils_get_project_references_stub then
			utils_get_project_references_stub:revert()
		end
		if utils_get_all_project_files_stub then
			utils_get_all_project_files_stub:revert()
		end
		if utils_get_nuget_config_file_stub then
			utils_get_nuget_config_file_stub:revert()
		end

		if picker_ask_user_for_choice_stub then
			picker_ask_user_for_choice_stub:revert()
		end

		if dotnet_handle_nugets_in_project_stub then
			dotnet_handle_nugets_in_project_stub:revert()
		end
		if dotnet_handle_project_reference_stub then
			dotnet_handle_project_reference_stub:revert()
		end
		if dotnet_add_project_to_solution_stub then
			dotnet_add_project_to_solution_stub:revert()
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
			utils_get_all_projects_in_solution_stub.returns({})

			sut.remove_nuget_from_project()

			assert.stub(vim_notify_stub).was_called_with("No projects in solution", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ nil })

			sut.remove_nuget_from_project()

			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give a warning if there are no NuGets in the project", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1" })
			nugets_all_nugets_stub.returns({}) -- no packages

			sut.remove_nuget_from_project()

			assert.stub(vim_notify_stub).was_called_with("No nugets in project proj1", vim.log.levels.WARN)
		end)

		it("should give a warning if no NuGets are selected for removal by the user", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1", nil })
			nugets_all_nugets_stub.returns({ "Moq", "NUnit" })

			sut.remove_nuget_from_project()

			assert.stub(vim_notify_stub).was_called_with("No nuget chosen", vim.log.levels.WARN)
		end)

		it("should call handle_nugets_in_project with correct args", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1", "Moq" })
			nugets_all_nugets_stub.returns({ "Moq", "NUnit" })

			sut.remove_nuget_from_project()

			assert.stub(dotnet_handle_nugets_in_project_stub).was_called_with("Remove", {
				{
					argv = { "dotnet", "remove", "proj1", "package" },
					items = { "Moq" },
				},
			})
		end)
	end)

	describe("update_nugets_in_project", function()
		it("should give an error if no project is selected", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1" })
			stub_picker_choices({ nil })

			sut.update_nugets_in_project()

			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give a warning if there are no outdated NuGets in the project", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1" })
			nugets_outdated_nugets_stub.returns({}) -- none outdated

			sut.update_nugets_in_project()

			assert.stub(vim_notify_stub).was_called_with("No outdated nugets in project proj1", vim.log.levels.WARN)
		end)

		it("should call handle_nugets_in_project with correct args", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1" })
			nugets_outdated_nugets_stub.returns({ "Moq", "NUnit" }, nil)

			sut.update_nugets_in_project()

			assert.stub(dotnet_handle_nugets_in_project_stub).was_called_with("Update", {
				{
					argv = { "dotnet", "add", "proj1", "package" },
					items = { "Moq", "NUnit" },
				},
			})
		end)
	end)

	describe("add_project_reference", function()
		it("should give an error if no projects exist in solution", function()
			utils_get_all_projects_in_solution_stub.returns({})

			sut.add_project_reference()

			assert.stub(vim_notify_stub).was_called_with("No projects in solution", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ nil })

			sut.add_project_reference()

			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should give an error if no project to reference is selected", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1", nil })

			sut.add_project_reference()

			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call handle_project_reference with correct args", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ "proj1", "proj2" })

			sut.add_project_reference()

			assert.stub(dotnet_handle_project_reference_stub).was_called_with("add", "proj1", "proj2")
		end)
	end)

	describe("remove_project_reference", function()
		it("should give an error if no projects exist in solution", function()
			utils_get_all_projects_in_solution_stub.returns({})

			sut.remove_project_reference()

			assert.stub(vim_notify_stub).was_called_with("No projects in solution", vim.log.levels.ERROR)
		end)

		it("should give an error if no project is selected", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			stub_picker_choices({ nil })

			sut.remove_project_reference()

			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call handle_project_reference with correct args", function()
			utils_get_all_projects_in_solution_stub.returns({ "proj1", "proj2" })
			utils_get_project_references_stub.returns({ "proj2" })
			stub_picker_choices({ "proj1", "proj2" })

			sut.remove_project_reference()

			assert.stub(dotnet_handle_project_reference_stub).was_called_with("remove", "proj1", "proj2")
		end)
	end)

	describe("add_project_to_solution", function()
		it("should warn if there are no csproj files that are not already in solution", function()
			utils_get_all_project_files_stub.returns({})
			utils_get_all_projects_in_solution_stub.returns({ "proj1" })

			sut.add_project_to_solution()

			assert
				.stub(vim_notify_stub)
				.was_called_with("No csproj files that are not already in solution", vim.log.levels.WARN)
		end)

		it("should give an error if user cancels project selection", function()
			utils_get_all_project_files_stub.returns({ "proj1" })
			utils_get_all_projects_in_solution_stub.returns({ "proj2" })
			stub_picker_choices({ nil })

			sut.add_project_to_solution()

			assert.stub(vim_notify_stub).was_called_with("No project chosen", vim.log.levels.ERROR)
		end)

		it("should call add_project_to_solution with correct args", function()
			utils_get_all_project_files_stub.returns({ "proj1" })
			utils_get_all_projects_in_solution_stub.returns({ "proj2" })
			stub_picker_choices({ "proj1" })

			sut.add_project_to_solution()

			assert.stub(dotnet_add_project_to_solution_stub).was_called_with("/fake/path/to/solution.sln", "proj1")
		end)
	end)
end)
