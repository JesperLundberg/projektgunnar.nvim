local assert = require("luassert")
local stub = require("luassert.stub")

describe("async", function()
	local async = require("projektgunnar.async")

	local notify_stub

	before_each(function()
		notify_stub = stub(vim, "notify")
	end)

	after_each(function()
		if notify_stub then
			notify_stub:revert()
		end
	end)

	-- Pump the event loop until predicate is true (or timeout)
	local function wait_for(pred)
		return vim.wait(1000, pred, 5)
	end

	describe("run", function()
		it("should run the function on the main loop, not synchronously", function()
			local ran = false
			async.run(function()
				ran = true
			end)

			assert.is_false(ran)
			assert.is_true(wait_for(function()
				return ran
			end))
		end)

		it("should pass extra arguments to the function", function()
			local got
			async.run(function(a, b)
				got = { a, b }
			end, "x", 42)

			assert.is_true(wait_for(function()
				return got ~= nil
			end))
			assert.are.same({ "x", 42 }, got)
		end)

		it("should notify when the function raises an error", function()
			async.run(function()
				error("boom")
			end)

			assert.is_true(wait_for(function()
				return #notify_stub.calls > 0
			end))
			local msg = notify_stub.calls[1].refs[1]
			assert.is_truthy(msg:find("Async error:", 1, true))
			assert.is_truthy(msg:find("boom", 1, true))
			assert.are.equal(vim.log.levels.ERROR, notify_stub.calls[1].refs[2])
		end)

		it("should notify when an error is raised after an await", function()
			local wrapped = async.wrap_cb(function(cb)
				cb()
			end)

			async.run(function()
				wrapped()
				error("late boom")
			end)

			assert.is_true(wait_for(function()
				return #notify_stub.calls > 0
			end))
			assert.is_truthy(notify_stub.calls[1].refs[1]:find("late boom", 1, true))
		end)
	end)

	describe("wrap_cb", function()
		it("should return the values passed to the callback", function()
			local wrapped = async.wrap_cb(function(cb)
				cb("a", "b", 3)
			end)

			local got
			async.run(function()
				got = { wrapped() }
			end)

			assert.is_true(wait_for(function()
				return got ~= nil
			end))
			assert.are.same({ "a", "b", 3 }, got)
		end)

		it("should append the callback after the supplied arguments", function()
			local received
			local wrapped = async.wrap_cb(function(x, y, cb)
				received = { x, y }
				cb(x + y)
			end)

			local result
			async.run(function()
				result = wrapped(2, 3)
			end)

			assert.is_true(wait_for(function()
				return result ~= nil
			end))
			assert.are.same({ 2, 3 }, received)
			assert.are.equal(5, result)
		end)

		it("should suspend until the callback is invoked later", function()
			local saved_cb
			local wrapped = async.wrap_cb(function(cb)
				saved_cb = cb
			end)

			local result = "unset"
			async.run(function()
				result = wrapped()
			end)

			assert.is_true(wait_for(function()
				return saved_cb ~= nil
			end))
			-- still suspended
			vim.wait(20)
			assert.are.equal("unset", result)

			saved_cb("done")
			assert.is_true(wait_for(function()
				return result == "done"
			end))
		end)

		it("should support callbacks that fire from a fast event context", function()
			local timer = vim.uv.new_timer()
			local wrapped = async.wrap_cb(function(cb)
				timer:start(1, 0, function()
					timer:close()
					cb("from timer")
				end)
			end)

			local result
			async.run(function()
				result = wrapped()
			end)

			assert.is_true(wait_for(function()
				return result ~= nil
			end))
			assert.are.equal("from timer", result)
		end)

		it("should allow several awaits in sequence", function()
			local counter = 0
			local wrapped = async.wrap_cb(function(cb)
				counter = counter + 1
				cb(counter)
			end)

			local results = {}
			async.run(function()
				results[#results + 1] = wrapped()
				results[#results + 1] = wrapped()
				results[#results + 1] = wrapped()
			end)

			assert.is_true(wait_for(function()
				return #results == 3
			end))
			assert.are.same({ 1, 2, 3 }, results)
		end)
	end)

	describe("system", function()
		local system_stub

		before_each(function()
			system_stub = stub(vim, "system")
		end)

		after_each(function()
			if system_stub then
				system_stub:revert()
			end
		end)

		local function run_system(cmd, opts)
			local got
			async.run(function()
				got = { async.system(cmd, opts) }
			end)
			assert.is_true(wait_for(function()
				return got ~= nil
			end))
			return got
		end

		it("should return stdout lines, stderr and exit code", function()
			system_stub.invokes(function(_, _, on_exit)
				on_exit({ stdout = "one\ntwo\n", stderr = "warn", code = 0 })
			end)

			local got = run_system({ "echo", "hi" })

			assert.are.same({ "one", "two" }, got[1])
			assert.are.equal("warn", got[2])
			assert.are.equal(0, got[3])
		end)

		it("should trim leading and trailing empty lines but keep interior ones", function()
			system_stub.invokes(function(_, _, on_exit)
				on_exit({ stdout = "\n\na\n\nb\n\n", stderr = "", code = 0 })
			end)

			local got = run_system({ "x" })

			assert.are.same({ "a", "", "b" }, got[1])
		end)

		it("should default missing fields", function()
			system_stub.invokes(function(_, _, on_exit)
				on_exit({})
			end)

			local got = run_system({ "x" })

			assert.are.same({}, got[1])
			assert.are.equal("", got[2])
			assert.are.equal(-1, got[3])
		end)

		it("should pass the command and force text = true by default", function()
			system_stub.invokes(function(_, _, on_exit)
				on_exit({ stdout = "", stderr = "", code = 0 })
			end)

			run_system({ "dotnet", "--version" })

			local call = system_stub.calls[1].refs
			assert.are.same({ "dotnet", "--version" }, call[1])
			assert.is_true(call[2].text)
		end)

		it("should let the caller override options", function()
			system_stub.invokes(function(_, _, on_exit)
				on_exit({ stdout = "", stderr = "", code = 0 })
			end)

			run_system({ "x" }, { text = false, cwd = "/tmp" })

			local opts = system_stub.calls[1].refs[2]
			assert.is_false(opts.text)
			assert.are.equal("/tmp", opts.cwd)
		end)

		it("should report a non-zero exit code", function()
			system_stub.invokes(function(_, _, on_exit)
				on_exit({ stdout = "", stderr = "bad", code = 3 })
			end)

			local got = run_system({ "x" })

			assert.are.equal(3, got[3])
			assert.are.equal("bad", got[2])
		end)
	end)

	describe("ui", function()
		-- plenary runs every `it` inside a coroutine, so async.ui would take its
		-- "inside a coroutine" path. Calling it from a vim.schedule callback
		-- gives us a plain main-thread context with no coroutine.
		local function call_outside_coroutine(f)
			local state = { called = false }
			vim.schedule(function()
				state.running = coroutine.running()
				state.ret = f()
				state.called = true
			end)
			assert.is_true(wait_for(function()
				return state.called
			end))
			return state
		end

		it("should schedule fn and return immediately when called outside a coroutine", function()
			local ran = false
			local ran_inline
			local state = call_outside_coroutine(function()
				local ret = async.ui(function()
					ran = true
				end)
				-- checked in the same tick, before the event loop can run fn
				ran_inline = ran
				return ret
			end)

			assert.is_nil(state.running)
			assert.is_nil(state.ret)
			assert.is_false(ran_inline)
			assert.is_true(wait_for(function()
				return ran
			end))
		end)

		it("should pass arguments to fn", function()
			local got
			call_outside_coroutine(function()
				async.ui(function(a, b)
					got = { a, b }
				end, 1, 2)
			end)

			assert.is_true(wait_for(function()
				return got ~= nil
			end))
			assert.are.same({ 1, 2 }, got)
		end)

		it("should await fn when called inside a coroutine", function()
			local order = {}
			async.run(function()
				async.ui(function()
					order[#order + 1] = "ui"
				end)
				order[#order + 1] = "after"
			end)

			assert.is_true(wait_for(function()
				return #order == 2
			end))
			assert.are.same({ "ui", "after" }, order)
		end)

		it("should notify on error and keep the coroutine going", function()
			local finished = false
			async.run(function()
				async.ui(function()
					error("ui boom")
				end)
				finished = true
			end)

			assert.is_true(wait_for(function()
				return finished
			end))
			assert.stub(notify_stub).was_called(1)
			local msg = notify_stub.calls[1].refs[1]
			assert.is_truthy(msg:find("UI error:", 1, true))
			assert.is_truthy(msg:find("ui boom", 1, true))
			assert.are.equal(vim.log.levels.ERROR, notify_stub.calls[1].refs[2])
		end)

		it("should notify on error when called outside a coroutine", function()
			call_outside_coroutine(function()
				async.ui(function()
					error("outside boom")
				end)
			end)

			assert.is_true(wait_for(function()
				return #notify_stub.calls > 0
			end))
			assert.is_truthy(notify_stub.calls[1].refs[1]:find("outside boom", 1, true))
		end)
	end)
end)
