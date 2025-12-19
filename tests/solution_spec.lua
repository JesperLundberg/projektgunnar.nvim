local assert = require("luassert")
local stub = require("luassert.stub")

describe("solution", function()
	local utils
	local picker
	local solution

	-- Stubs
	local notify_stub
	local getcwd_stub
	local realpath_stub
	local utils_get_all_solution_files_stub
	local picker_ask_user_for_choice_stub

	-- Reload a fresh module instance so module-local cache resets per test.
	local function reload_solution_module()
		package.loaded["projektgunnar.solution"] = nil
		solution = require("projektgunnar.solution")
	end

	before_each(function()
		utils = require("projektgunnar.utils")
		picker = require("projektgunnar.picker")

		-- Stub vim APIs used by solution.lua.
		notify_stub = stub(vim, "notify")
		getcwd_stub = stub(vim.fn, "getcwd")
		realpath_stub = stub(vim.uv, "fs_realpath")

		-- Deterministic cwd/realpath for stable cache keys and relative paths.
		getcwd_stub.returns("/repo")
		realpath_stub.returns("/repo")

		-- Fresh cache per test.
		reload_solution_module()

		-- Stub dependencies.
		utils_get_all_solution_files_stub = stub(utils, "get_all_solution_files")
		picker_ask_user_for_choice_stub = stub(picker, "ask_user_for_choice")
	end)

	after_each(function()
		if notify_stub then
			notify_stub:revert()
		end
		if getcwd_stub then
			getcwd_stub:revert()
		end
		if realpath_stub then
			realpath_stub:revert()
		end
		if utils_get_all_solution_files_stub then
			utils_get_all_solution_files_stub:revert()
		end
		if picker_ask_user_for_choice_stub then
			picker_ask_user_for_choice_stub:revert()
		end
	end)

	describe("resolve", function()
		it("should call cb(nil) when no .sln exists under cwd", function()
			utils_get_all_solution_files_stub.returns({})

			local solution_file = ""
			solution.resolve(function(sln)
				solution_file = sln
			end)

			assert.is_nil(solution_file)
		end)

		it("should notify error when no .sln exists under cwd", function()
			utils_get_all_solution_files_stub.returns({})

			solution.resolve(function(_) end)

			assert.stub(notify_stub).was_called_with("No .sln found under cwd", vim.log.levels.ERROR)
		end)

		it("should auto-select the only solution when exactly one exists", function()
			utils_get_all_solution_files_stub.returns({ "/repo/a.sln" })

			local solution_file
			solution.resolve(function(sln)
				solution_file = sln
			end)

			assert.are.equal("/repo/a.sln", solution_file)
		end)

		it("should not call picker when exactly one solution exists", function()
			utils_get_all_solution_files_stub.returns({ "/repo/a.sln" })

			solution.resolve(function(_) end)

			assert.stub(picker_ask_user_for_choice_stub).was_called(0)
		end)

		it("should cache the only solution so it does not re-scan on second resolve", function()
			utils_get_all_solution_files_stub.returns({ "/repo/a.sln" })

			solution.resolve(function(_) end)
			solution.resolve(function(_) end)

			assert.stub(utils_get_all_solution_files_stub).was_called(1)
		end)

		it("should call picker when multiple solutions exist", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
				cb("a.sln")
			end)

			solution.resolve(function(_) end)

			assert.stub(picker_ask_user_for_choice_stub).was_called(1)
		end)

		it("should pass relative display items to picker when multiple solutions exist", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, items, cb)
				assert.are.same({ "a.sln", "sub/b.sln" }, items)
				cb("a.sln")
			end)

			solution.resolve(function(_) end)
		end)

		it("should return absolute path to cb even though picker returns relative choice", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
				cb("sub/b.sln")
			end)

			local solution_file
			solution.resolve(function(sln)
				solution_file = sln
			end)

			assert.are.equal("/repo/sub/b.sln", solution_file)
		end)

		it("should call cb(nil) when user cancels picker", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
				cb(nil)
			end)

			local solution_file = ""
			solution.resolve(function(sln)
				solution_file = sln
			end)

			assert.is_nil(solution_file)
		end)

		it("should cache chosen solution so picker is not called again on second resolve", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
				cb("a.sln")
			end)

			solution.resolve(function(_) end)
			solution.resolve(function(_) end)

			assert.stub(picker_ask_user_for_choice_stub).was_called(1)
		end)

		it("should cache chosen solution so it does not re-scan on second resolve", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
				cb("a.sln")
			end)

			solution.resolve(function(_) end)
			solution.resolve(function(_) end)

			assert.stub(utils_get_all_solution_files_stub).was_called(1)
		end)
	end)

	describe("forget", function()
		it("should cause resolve to re-scan after forget_cached_solution_file()", function()
			utils_get_all_solution_files_stub.returns({
				"/repo/a.sln",
				"/repo/sub/b.sln",
			})

			picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
				cb("a.sln")
			end)

			-- First resolve caches
			solution.resolve(function(_) end)

			-- Forget and resolve again should re-scan
			solution.forget_cached_solution_file()
			solution.resolve(function(_) end)

			assert.stub(utils_get_all_solution_files_stub).was_called(2)
		end)

		it(
			"should cause resolve to prompt again after forget_cached_solution_file() when multiple solutions exist",
			function()
				utils_get_all_solution_files_stub.returns({
					"/repo/a.sln",
					"/repo/sub/b.sln",
				})

				picker_ask_user_for_choice_stub.invokes(function(_, _, cb)
					cb("a.sln")
				end)

				-- First resolve caches
				solution.resolve(function(_) end)

				-- Forget and resolve again should prompt again
				solution.forget_cached_solution_file()
				solution.resolve(function(_) end)

				assert.stub(picker_ask_user_for_choice_stub).was_called(2)
			end
		)
	end)
end)
