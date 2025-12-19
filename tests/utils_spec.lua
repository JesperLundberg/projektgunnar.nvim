local assert = require("luassert")
local stub = require("luassert.stub")

describe("utils", function()
	local utils = require("projektgunnar.utils")

	describe("table_concat", function()
		it("should concatenate two tables", function()
			local t1 = { 1, 2, 3 }
			local t2 = { 4, 5, 6 }
			local result = utils.table_concat(t1, t2)
			assert.are.same({ 1, 2, 3, 4, 5, 6 }, result)
		end)

		it("should keep t1 unchanged when t2 is empty", function()
			local t1 = { 1, 2, 3 }
			local t2 = {}
			local result = utils.table_concat(t1, t2)
			assert.are.same({ 1, 2, 3 }, result)
		end)

		it("should return t2 when t1 is empty", function()
			local t1 = {}
			local t2 = { 4, 5 }
			local result = utils.table_concat(t1, t2)
			assert.are.same({ 4, 5 }, result)
		end)
	end)

	describe("has_value", function()
		it("should return true if the value exists", function()
			assert.is_true(utils.has_value({ 1, 2, 3 }, 2))
		end)

		it("should return false if the value does not exist", function()
			assert.is_false(utils.has_value({ 1, 2, 3 }, 999))
		end)

		it("should return false if table is nil", function()
			assert.is_false(utils.has_value(nil, 1))
		end)

		it("should return false if value is nil", function()
			assert.is_false(utils.has_value({ 1, 2, 3 }, nil))
		end)
	end)

	describe("prequire", function()
		it("should return module if it exists", function()
			local mod = utils.prequire("projektgunnar.utils")
			assert.are.same(utils, mod)
		end)

		it("should return nil if module does not exist", function()
			local mod = utils.prequire("projektgunnar.does_not_exist")
			assert.is_nil(mod)
		end)
	end)

	describe("get_all_solution_files", function()
		local getcwd_stub
		local glob_stub

		before_each(function()
			getcwd_stub = stub(vim.fn, "getcwd")
			glob_stub = stub(vim.fn, "glob")
		end)

		after_each(function()
			if getcwd_stub then
				getcwd_stub:revert()
			end
			if glob_stub then
				glob_stub:revert()
			end
		end)

		it("should return all .sln files under cwd", function()
			getcwd_stub.returns("/repo")
			glob_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			local result = utils.get_all_solution_files()

			-- We don't sort here; sorting is done in solution.resolve().
			assert.are.same({ "/repo/a.sln", "/repo/sub/b.sln" }, result)

			assert.stub(glob_stub).was_called_with("/repo/**/*.sln", false, true)
		end)

		it("should return an empty table when none are found", function()
			getcwd_stub.returns("/repo")
			glob_stub.returns({})

			local result = utils.get_all_solution_files()
			assert.are.same({}, result)
		end)
	end)

	describe("get_nuget_config_file", function()
		local getcwd_stub
		local glob_stub

		before_each(function()
			getcwd_stub = stub(vim.fn, "getcwd")
			glob_stub = stub(vim.fn, "glob")
		end)

		after_each(function()
			if getcwd_stub then
				getcwd_stub:revert()
			end
			if glob_stub then
				glob_stub:revert()
			end
		end)

		it("should return the first nuget.config found under cwd", function()
			getcwd_stub.returns("/repo")
			glob_stub.returns({
				"/repo/nuget.config",
				"/repo/sub/nuget.config",
			})

			local result = utils.get_nuget_config_file()
			assert.are.equal("/repo/nuget.config", result)

			assert.stub(glob_stub).was_called_with("/repo/**/nuget.config", false, true)
		end)

		it("should return nil when no nuget.config exists", function()
			getcwd_stub.returns("/repo")
			glob_stub.returns({})

			local result = utils.get_nuget_config_file()
			assert.is_nil(result)
		end)
	end)

	describe("get_project_references", function()
		local systemlist_stub

		before_each(function()
			systemlist_stub = stub(vim.fn, "systemlist")
		end)

		after_each(function()
			if systemlist_stub then
				systemlist_stub:revert()
			end
		end)

		it("should return reference list with './' removed and backslashes normalized", function()
			systemlist_stub.returns({
				"Project reference(s)",
				"--------------------",
				".\\ref1\\ref1.csproj",
				"./ref2/ref2.csproj",
			})

			local result = utils.get_project_references("proj1.csproj")

			-- First two lines are removed; each remaining line drops first 2 chars and normalizes slashes.
			assert.are.same({ "ref1/ref1.csproj", "ref2/ref2.csproj" }, result)

			assert.stub(systemlist_stub).was_called_with({ "dotnet", "list", "proj1.csproj", "reference" })
		end)

		it("should return empty list if only header lines exist", function()
			systemlist_stub.returns({
				"Project reference(s)",
				"--------------------",
			})

			local result = utils.get_project_references("proj1.csproj")
			assert.are.same({}, result)
		end)
	end)

	describe("get_all_projects_in_solution", function()
		local systemlist_stub

		before_each(function()
			systemlist_stub = stub(vim.fn, "systemlist")
		end)

		after_each(function()
			if systemlist_stub then
				systemlist_stub:revert()
			end
		end)

		it("should call dotnet sln <sln> list and return project list", function()
			systemlist_stub.returns({
				"Projects",
				"----------",
				"proj1.csproj",
				"proj2.csproj",
			})

			local sln = "/repo/MySolution.sln"
			local result = utils.get_all_projects_in_solution(sln)

			assert.are.same({ "proj1.csproj", "proj2.csproj" }, result)
			assert.stub(systemlist_stub).was_called_with({ "dotnet", "sln", sln, "list" })
		end)

		it("should return empty list when solution contains no projects", function()
			systemlist_stub.returns({
				"Projects",
				"----------",
			})

			local result = utils.get_all_projects_in_solution("/repo/MySolution.sln")
			assert.are.same({}, result)
		end)
	end)

	describe("get_all_project_files", function()
		local systemlist_stub

		before_each(function()
			systemlist_stub = stub(vim.fn, "systemlist")
		end)

		after_each(function()
			if systemlist_stub then
				systemlist_stub:revert()
			end
		end)

		it("should return all csproj files with leading './' removed", function()
			systemlist_stub.returns({
				"./a.csproj",
				"./folder/b.csproj",
			})

			local result = utils.get_all_project_files()

			assert.are.same({ "a.csproj", "folder/b.csproj" }, result)
			assert.stub(systemlist_stub).was_called_with({ "find", ".", "-name", "*.csproj" })
		end)
	end)
end)
