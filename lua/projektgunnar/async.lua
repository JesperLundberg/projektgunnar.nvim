local M = {}

local unpack = unpack or table.unpack

-- Safely resume coroutine on main loop (avoids "yield across C boundary")
local function resume_on_main(co, ...)
	local args = { ... }
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

-- Start a coroutine-based async flow
function M.run(fn, ...)
	local co = coroutine.create(fn)
	resume_on_main(co, ...)
end

-- Wrap a cb-last function: fn(..., cb) -> awaitable(...)
function M.wrap_cb(fn)
	return function(...)
		local args = { ... }
		return coroutine.yield(function(resume)
			table.insert(args, resume)
			fn(unpack(args))
		end)
	end
end

-- Await a vim.system call (returns stdout_lines, stderr, code)
function M.system(cmd, opts)
	opts = vim.tbl_extend("force", { text = true }, opts or {})
	return M.wrap_cb(function(cb)
		vim.system(cmd, opts, function(obj)
			local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
			cb(lines, obj.stderr or "", obj.code or -1)
		end)
	end)()
end

-- UI helper: kör UI-saker säkert på main-loop
function M.ui(fn, ...)
	local args = { ... }
	return M.wrap_cb(function(cb)
		vim.schedule(function()
			local ok, err = pcall(fn, unpack(args))
			if not ok then
				vim.notify("UI error: " .. tostring(err), vim.log.levels.ERROR)
			end
			cb()
		end)
	end)()
end

return M
