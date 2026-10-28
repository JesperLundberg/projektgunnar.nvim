-- Minimal coroutine-based async helpers for Neovim.
-- Provides: run, wrap_cb, system, ui (works both inside and outside coroutines).

local M = {}
local unpack = unpack or table.unpack

-- Safely resume a coroutine on the main loop (avoids "yield across C boundary").
-- Protocol: if the coroutine yields a function, it's treated as an
-- awaitable thunk — call it with a `resume` callback, and resume the
-- coroutine with whatever args that callback receives.
local function resume_on_main(co, ...)
	local args = { ... } -- capture varargs in this scope
	vim.schedule(function()
		local ok, ret = coroutine.resume(co, unpack(args))
		if not ok then
			vim.notify("Async error: " .. tostring(ret), vim.log.levels.ERROR)
			return
		end
		if type(ret) == "function" then
			ret(function(...)
				resume_on_main(co, ...)
			end)
		end
	end)
end

--- Start a coroutine-based async flow
--- @param fn function
function M.run(fn, ...)
	local co = coroutine.create(fn)
	resume_on_main(co, ...)
end

--- Wrap a callback-last function: fn(..., cb) -> awaitable(...)
--- The returned function can be called inside a coroutine to "await" the result.
function M.wrap_cb(fn)
	return function(...)
		local args = { ... }
		return coroutine.yield(function(resume)
			table.insert(args, resume)
			fn(unpack(args))
		end)
	end
end

--- Await a vim.system call
--- @param cmd string[] argv
--- @param opts table|nil (will force { text = true } unless overridden)
--- @return string[] lines, string stderr, integer code
function M.system(cmd, opts)
	opts = vim.tbl_extend("force", { text = true }, opts or {})
	return M.wrap_cb(function(cb)
		-- vim.system throws synchronously if the command cannot be spawned
		-- (e.g. executable not found). Report that as a failed run instead of
		-- crashing the coroutine, so callers can show the reason.
		local ok, err = pcall(vim.system, cmd, opts, function(obj)
			local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
			cb(lines, obj.stderr or "", obj.code or -1)
		end)
		if not ok then
			cb({}, tostring(err), -1)
		end
	end)()
end

-- Run `fn` safely on the main loop and report errors via vim.notify.
-- If called from inside a coroutine (started by M.run), this becomes
-- awaitable: the coroutine suspends until `fn` has run.
-- If called outside a coroutine, it just schedules `fn` and returns immediately.
function M.ui(fn, ...)
	local args = { ... }

	local function run_safely()
		local ok, err = xpcall(fn, function(e)
			return debug.traceback("UI error: " .. tostring(e), 2)
		end, unpack(args))
		if not ok then
			vim.notify(err, vim.log.levels.ERROR)
		end
	end

	if coroutine.running() == nil then
		vim.schedule(run_safely)
		return
	end

	-- Reuse the same await mechanism as M.system: yield a thunk that
	-- schedules the work and resumes us once it's done.
	return M.wrap_cb(function(cb)
		vim.schedule(function()
			run_safely()
			cb()
		end)
	end)()
end

return M
