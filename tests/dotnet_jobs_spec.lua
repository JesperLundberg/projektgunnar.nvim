local assert = require("luassert")
local stub = require("luassert.stub")

describe("dotnet_jobs", function()
	local dotnet_jobs = require("projektgunnar.dotnet_jobs")
	local ui = require("projektgunnar.ui")
	local async = require("projektgunnar.async")

	local buf
	local notify_stub
	local system_stub
	local stubs

	local function wait_for(pred)
		return vim.wait(1000, pred, 5)
	end

	-- Wait until the queue is finished (either "done" was drawn or a summary notified)
	local function wait_finished()
		return wait_for(function()
			return #stubs.done.calls > 0 or #notify_stub.calls > 0
		end)
	end

	-- Arguments a stub was called with (keeps trailing nils out, like the real call)
	local function args(s, n)
		return s.calls[n].refs
	end

	before_each(function()
		buf = vim.api.nvim_create_buf(false, true)

		notify_stub = stub(vim, "notify")

		stubs = {}
		for _, name in ipairs({ "print", "progress", "update", "done", "spinner", "clear_spinner" }) do
			stubs[name] = stub(ui.result, name)
		end
		stubs.open = stub(ui.result, "open")
		stubs.open.returns(buf)

		system_stub = stub(async, "system")
		system_stub.returns({}, "", 0)
	end)

	after_each(function()
		for _, s in pairs(stubs) do
			s:revert()
		end
		system_stub:revert()
		notify_stub:revert()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end)

	describe("handle_nugets_in_project", function()
		it("should open the window, print the intro and run one command per item", function()
			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo", "Bar" } },
			}, "project")

			assert.is_true(wait_finished())

			assert.stub(stubs.open).was_called(1)
			assert.stub(stubs.print).was_called_with(buf, "Add nugets in project")

			assert.stub(system_stub).was_called(2)
			assert.are.same({ "dotnet", "add", "p.csproj", "package", "Foo" }, args(system_stub, 1)[1])
			assert.are.same({ "dotnet", "add", "p.csproj", "package", "Bar" }, args(system_stub, 2)[1])
			assert.is_true(args(system_stub, 1)[2].text)

			assert.stub(stubs.done).was_called_with(buf)
		end)

		it("should mention the solution in the intro when scope is solution", function()
			dotnet_jobs.handle_nugets_in_project("Update", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "solution")

			assert.is_true(wait_finished())
			assert.stub(stubs.print).was_called_with(buf, "Update nugets in solution")
		end)

		it("should default to project in the intro when no scope is given", function()
			dotnet_jobs.handle_nugets_in_project("Remove", {
				{ argv = { "dotnet", "remove", "p.csproj", "package" }, items = { "Foo" } },
			})

			assert.is_true(wait_finished())
			assert.stub(stubs.print).was_called_with(buf, "Remove nugets in project")
		end)

		it("should not show project progress when there is only one command", function()
			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "project")

			assert.is_true(wait_finished())
			assert.stub(stubs.progress).was_not_called()
		end)

		it("should show project progress when there are several commands", function()
			dotnet_jobs.handle_nugets_in_project("Update", {
				{ argv = { "dotnet", "add", "a.csproj", "package" }, items = { "Foo" } },
				{ argv = { "dotnet", "add", "b.csproj", "package" }, items = { "Bar" } },
			}, "solution")

			assert.is_true(wait_finished())
			assert.stub(stubs.progress).was_called(2)
			assert.stub(stubs.progress).was_called_with(buf, 1, 2)
			assert.stub(stubs.progress).was_called_with(buf, 2, 2)
			assert.stub(system_stub).was_called(2)
		end)

		it("should report success without output", function()
			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "project")

			assert.is_true(wait_finished())

			local a = args(stubs.update, 1)
			assert.are.same({ buf, 1, 1, true, "dotnet add p.csproj package Foo", "Foo" }, vim.list_slice(a, 1, 6))
			assert.is_nil(a[7])
		end)

		it("should start and stop the spinner around every command", function()
			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo", "Bar" } },
			}, "project")

			assert.is_true(wait_finished())
			assert.stub(stubs.spinner).was_called(2)
			assert.stub(stubs.clear_spinner).was_called(2)
		end)
	end)

	describe("failed commands", function()
		it("should pass stdout and stderr of a failed command to the result window", function()
			system_stub.returns({ "error: NU1101", "Unable to find package Foo" }, "stderr line\n", 1)

			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "project")

			assert.is_true(wait_finished())

			local a = args(stubs.update, 1)
			assert.is_false(a[4])
			assert.are.same({ "error: NU1101", "Unable to find package Foo", "stderr line" }, a[7])
		end)

		it("should drop empty lines and carriage returns from the output", function()
			system_stub.returns({ "", "error: bad\r", "   " }, "\n\n", 1)

			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "project")

			assert.is_true(wait_finished())
			assert.are.same({ "error: bad" }, args(stubs.update, 1)[7])
		end)

		it("should only keep the last 10 lines of output", function()
			local many = {}
			for i = 1, 15 do
				many[i] = "line " .. i
			end
			system_stub.returns(many, "", 1)

			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "project")

			assert.is_true(wait_finished())

			local output = args(stubs.update, 1)[7]
			assert.are.equal(10, #output)
			assert.are.equal("line 6", output[1])
			assert.are.equal("line 15", output[10])
		end)

		it("should keep going with the remaining items after a failure", function()
			local n = 0
			system_stub.invokes(function()
				n = n + 1
				if n == 1 then
					return {}, "boom", 1
				end
				return {}, "", 0
			end)

			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo", "Bar" } },
			}, "project")

			assert.is_true(wait_finished())
			assert.stub(system_stub).was_called(2)
			assert.is_false(args(stubs.update, 1)[4])
			assert.is_true(args(stubs.update, 2)[4])
		end)
	end)

	describe("when the result window is closed", function()
		it("should clean up the spinner when the buffer is wiped", function()
			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "Foo" } },
			}, "project")

			vim.api.nvim_buf_delete(buf, { force = true })

			assert.stub(stubs.clear_spinner).was_called_with(buf)

			-- let the (now window-less) queue finish so it cannot leak into the next test
			assert.is_true(wait_finished())
		end)

		it("should still run the remaining commands but stop drawing, then notify", function()
			local n = 0
			system_stub.invokes(function()
				n = n + 1
				if n == 1 then
					vim.api.nvim_buf_delete(buf, { force = true })
				end
				return {}, "", 0
			end)

			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "A", "B", "C" } },
			}, "project")

			assert.is_true(wait_finished())

			assert.stub(system_stub).was_called(3)
			assert.stub(stubs.update).was_not_called()
			assert.stub(stubs.done).was_not_called()
			assert.stub(stubs.spinner).was_called(1) -- only before the window closed
			assert
				.stub(notify_stub)
				.was_called_with("ProjektGunnar: finished, 3 commands succeeded", vim.log.levels.INFO)
		end)

		it("should warn with the number of failures in the summary", function()
			local n = 0
			system_stub.invokes(function()
				n = n + 1
				if n == 1 then
					vim.api.nvim_buf_delete(buf, { force = true })
				end
				return {}, "bad", (n == 2) and 1 or 0
			end)

			dotnet_jobs.handle_nugets_in_project("Add", {
				{ argv = { "dotnet", "add", "p.csproj", "package" }, items = { "A", "B", "C" } },
			}, "project")

			assert.is_true(wait_finished())
			assert
				.stub(notify_stub)
				.was_called_with("ProjektGunnar: finished, 1 of 3 commands failed", vim.log.levels.WARN)
		end)
	end)

	describe("handle_project_reference", function()
		it("should add a project reference", function()
			dotnet_jobs.handle_project_reference("add", "a.csproj", "b.csproj")

			assert.is_true(wait_finished())
			assert.stub(stubs.print).was_called_with(buf, "Adding project b.csproj to project a.csproj")
			assert.are.same({ "dotnet", "add", "a.csproj", "reference", "b.csproj" }, args(system_stub, 1)[1])
		end)

		it("should remove a project reference", function()
			dotnet_jobs.handle_project_reference("remove", "a.csproj", "b.csproj")

			assert.is_true(wait_finished())
			assert.stub(stubs.print).was_called_with(buf, "Removing project b.csproj from project a.csproj")
			assert.are.same({ "dotnet", "remove", "a.csproj", "reference", "b.csproj" }, args(system_stub, 1)[1])
		end)
	end)

	describe("add_project_to_solution", function()
		it("should run dotnet sln add", function()
			dotnet_jobs.add_project_to_solution("s.sln", "p.csproj")

			assert.is_true(wait_finished())
			assert.stub(stubs.print).was_called_with(buf, "Adding project p.csproj to solution")
			assert.are.same({ "dotnet", "sln", "s.sln", "add", "p.csproj" }, args(system_stub, 1)[1])
		end)
	end)
end)
