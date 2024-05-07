local assert = require("luassert")

-- import the luassert.mock module
local mock = require("luassert.mock")
local stub = require("luassert.stub")

describe("utils", function()
	local utils = require("lua.projektgunnar.utils")

	describe("table_concat", function()
		it("should concatenate two tables", function()
			local t1 = { 1, 2, 3 }
			local t2 = { 4, 5, 6 }
			local result = utils.table_concat(t1, t2)
			assert.are.same(result, { 1, 2, 3, 4, 5, 6 })
		end)

		it("should concatenate two tables where the second is empty", function()
			local t1 = { 1, 2, 3 }
			local t2 = {}
			local result = utils.table_concat(t1, t2)
			assert.are.same(result, { 1, 2, 3 })
		end)

		it("should concatenate two tables where the first is empty", function()
			local t1 = {}
			local t2 = { 4, 5, 6 }
			local result = utils.table_concat(t1, t2)
			assert.are.same(result, { 4, 5, 6 })
		end)

		it("should concatenate two tables where both are empty", function()
			local t1 = {}
			local t2 = {}
			local result = utils.table_concat(t1, t2)
			assert.are.same(result, {})
		end)
	end)

	describe("has_value", function()
		it("should return true if the value is in the table", function()
			local tab = { 1, 2, 3 }
			local val = 2
			local result = utils.has_value(tab, val)
			assert.is_true(result)
		end)

		it("should return false if the value is not in the table", function()
			local tab = { 1, 2, 3 }
			local val = 4
			local result = utils.has_value(tab, val)
			assert.is_false(result)
		end)

		it("should return false if the table is empty", function()
			local tab = {}
			local val = 4
			local result = utils.has_value(tab, val)
			assert.is_false(result)
		end)

		it("should return false if the value is nil", function()
			local tab = { 1, 2, 3 }
			local val = nil
			local result = utils.has_value(tab, val)
			assert.is_false(result)
		end)

		it("should return false if the table is nil", function()
			local tab = nil
			local val = 4
			local result = utils.has_value(tab, val)
			assert.is_false(result)
		end)
	end)

	describe("get_all_projects_in_solution_folder_not_in_solution", function()
		it("should return all projects that are not already in the solution file", function()
			-- mock vim.fn
			local fn = stub(vim.fn, "systemlist")

			-- set expectation when mocked api call made
			fn.returns({
				"./not_in_sln_project1.csproj",
				"./folder/not_in_sln_project2.csproj",
				"./folder2/test/not_in_sln_project3.csproj",
			})

			local result = utils.get_all_projects_in_solution_folder_not_in_solution()
			assert.are.same(result, {
				"not_in_sln_project1.csproj",
				"folder/not_in_sln_project2.csproj",
				"folder2/test/not_in_sln_project3.csproj",
			})

			mock.revert(fn)
		end)
	end)

	describe("get_all_projects_in_solution", function()
		it("should return all projects in the solution", function()
			-- mock vim.fn
			local fn = stub(vim.fn, "systemlist")

			-- set expectation when mocked api call made
			fn.returns({
				"Projects",
				"----------",
				"project1.csproj",
				"project2.csproj",
				"project3.csproj",
			})

			local result = utils.get_all_projects_in_solution()
			assert.are.same(result, {
				"project1.csproj",
				"project2.csproj",
				"project3.csproj",
			})

			mock.revert(fn)
		end)

		it("should return all projects in the solution when there are no projects", function()
			-- mock vim.fn
			local fn = stub(vim.fn, "systemlist")

			-- set expectation when mocked api call made
			fn.returns({
				"Projects",
				"----------",
			})

			local result = utils.get_all_projects_in_solution()
			assert.are.same(result, {})

			mock.revert(fn)
		end)
	end)

	describe("prequire", function()
		it("should return the module if it exists", function()
			local result = utils.prequire("lua.projektgunnar.utils")
			assert.are.same(result, utils)
		end)

		it("should return nil if the module does not exist", function()
			local result = utils.prequire("lua.projektgunnar.utils2")
			assert.is_nil(result)
		end)
	end)
end)
