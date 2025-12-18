local utils = require("projektgunnar.utils")
local picker = require("projektgunnar.picker")

local M = {}

local cache = {}

local function relative_to_cwd(path)
	local cwd = vim.fn.getcwd()
	-- Ensure cwd ends with path separator
	if not cwd:match("/$") then
		cwd = cwd .. "/"
	end
	return path:gsub("^" .. vim.pesc(cwd), "")
end

local function table_key()
	return vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
end

--- Resolve solution file for current cwd.
--- - If cached: returns it
--- - If exactly one found under cwd: caches + returns
--- - If many: prompts user, caches choice
--- @param cb fun(sln_path: string|nil)
function M.resolve(cb)
	local key = table_key()

	if cache[key] then
		cb(cache[key])
		return
	end

	local solution_files = utils.get_all_solution_files()
	table.sort(solution_files)

	if #solution_files == 0 then
		vim.notify("No .sln found under cwd", vim.log.levels.ERROR)
		cb(nil)
		return
	end

	if #solution_files == 1 then
		cache[key] = solution_files[1]
		cb(solution_files[1])
		return
	end

	local display_items = {}
	local by_display = {}

	for _, sln in ipairs(solution_files) do
		local display = relative_to_cwd(sln)
		display_items[#display_items + 1] = display
		by_display[display] = sln
	end

	picker.ask_user_for_choice("Choose solution file", display_items, function(choice)
		if not choice then
			cb(nil)
			return
		end

		local sln_path = by_display[choice]
		cache[key] = sln_path
		cb(sln_path)
	end)
end

--- Forget cached solution file for current cwd.
function M.forget()
	cache[table_key()] = nil
end

return M
