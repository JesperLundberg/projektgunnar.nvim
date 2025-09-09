local ui = require("projektgunnar.ui")
local async = require("projektgunnar.async")
local uv = vim.loop

local api = vim.api
local M = {}

-- Keep one timer per result buffer so multiple runs don't conflict
local SpinTimers = {}

-- Start a spinner that ticks every 80ms for the given buffer
local function start_spinner(buf)
	-- Stop any existing spinner for this buffer
	if SpinTimers[buf] then
		SpinTimers[buf]:stop()
		SpinTimers[buf]:close()
		SpinTimers[buf] = nil
	end

	local t = uv.new_timer()
	SpinTimers[buf] = t

	t:start(0, 80, function()
		vim.schedule(function()
			if api.nvim_buf_is_valid(buf) then
				ui.result.spinner(buf)
			else
				-- Buffer disappeared; stop ticking
				if SpinTimers[buf] then
					SpinTimers[buf]:stop()
					SpinTimers[buf]:close()
					SpinTimers[buf] = nil
				end
			end
		end)
	end)
end

-- Stop spinner; if clear == true, remove spinner line(s) from the buffer
local function stop_spinner(buf, clear)
	local t = SpinTimers[buf]
	if t then
		t:stop()
		t:close()
		SpinTimers[buf] = nil
	end
	if clear and api.nvim_buf_is_valid(buf) then
		ui.result.clear_spinner(buf)
	end
end

-- Run a queue of commands sequentially as a linear async flow.
-- Each entry shape:
--   {
--     argv  = { "dotnet", "add", "<project.csproj>", "package" }, -- base argv
--     items = { "Newtonsoft.Json", "Serilog" },                   -- appended one-by-one
--   }
local function run_queue(buf, command_and_items)
	async.run(function()
		local total_commands = #command_and_items

		for ci, entry in ipairs(command_and_items) do
			-- High-level progress (which command in the queue)
			async.ui(ui.result.progress, buf, ci, total_commands)

			local base_command = entry.argv or {}
			local items = entry.items or {}
			local total_items = #items

			for ii, item in ipairs(items) do
				-- Build argv per item: copy base and append item
				local argv = vim.deepcopy(base_command)
				table.insert(argv, item)

				-- Start spinner before the long-running command
				start_spinner(buf)

				-- Execute the command and await completion
				local _, _, code = async.system(argv, { text = true })

				-- Stop spinner and clear spinner line
				stop_spinner(buf, true)

				-- Update per-item status in the floating window
				local success = (code == 0)
				local argsToPrint = table.concat(argv or {}, " ")
				async.ui(ui.result.update, buf, ii, total_items, success, argsToPrint)
			end
		end

		-- All commands done
		async.ui(ui.result.done, buf)
	end)
end

--- Add or update nugets in a project/solution
--- @param action string -- e.g. "Adding"/"Updating" (used only for the message)
--- @param command_and_nugets table -- entries with { argv = {...}, items = {...} }
function M.handle_nugets_in_project(action, command_and_nugets)
	local buf = ui.result.open()
	local scope = (#command_and_nugets == 1) and " project" or " solution"

	-- Intro line
	async.ui(ui.result.print, buf, action .. " nugets in" .. scope)

	-- Ensure spinner timer is cleaned up if the result buffer is wiped
	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			stop_spinner(buf, false)
		end,
	})

	run_queue(buf, command_and_nugets)
end

--- Add or remove a project reference
--- @param action "add"|"remove"
--- @param project_path string
--- @param project_reference_path string
function M.handle_project_reference(action, project_path, project_reference_path)
	local buf = ui.result.open()

	if action == "add" then
		async.ui(ui.result.print, buf, ("Adding project %s to project %s"):format(project_reference_path, project_path))
	else
		async.ui(
			ui.result.print,
			buf,
			("Removing project %s from project %s"):format(project_reference_path, project_path)
		)
	end

	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			stop_spinner(buf, false)
		end,
	})

	local command_and_project = {
		{ argv = { "dotnet", action, project_path, "reference" }, items = { project_reference_path } },
	}

	run_queue(buf, command_and_project)
end

--- Add a project to the current solution
--- @param project_to_add_path string
function M.add_project_to_solution(project_to_add_path)
	local buf = ui.result.open()

	async.ui(ui.result.print, buf, "Adding project " .. project_to_add_path .. " to solution")

	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			stop_spinner(buf, false)
		end,
	})

	local command_and_project = {
		{ argv = { "dotnet", "sln", "add" }, items = { project_to_add_path } },
	}

	run_queue(buf, command_and_project)
end

return M
